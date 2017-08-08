library(digest)
source('import_data/read_config_file.R')
source('import_data/connect_to_neo4j.R')
# Function converting strings that look like numbers into numbers
make_numbers_numbers <- function(x) {
  suppressWarnings(  x[(!is.na(as.numeric(as.character(x))))] <- as.numeric(x[!is.na(as.numeric(as.character(x)))])  )
  x
}

# Function checking if a number is integer
is.wholenumber <- function(x, tol = .Machine$double.eps^0.5)  abs(x - round(x)) < tol

# Guess vector class (logical/character/integer/numeric)
guess_class <- function (x){
  x<-na.omit(x)
  if (length(setdiff(unique(x), c(0,1,'0','1',T, F)))==0) 'logical'
  else if (suppressWarnings(any(is.na(as.numeric(as.character(x)))))) 'character'
  else if (all(is.wholenumber(as.numeric(x)), na.rm = T)) 'integer'
  else 'numeric'
}

# Take data.table, create a query string for neo4j import based on field types
create_query_string <- function (data_file, forced_classes = list()){
  fields<-data.table(field = names(data_file), fclass = sapply(data_file, guess_class))
  for (field_name in names(forced_classes)) 
    fields[field==field_name, fclass:=forced_classes[[field_name]]]
  fields[fclass=='character', qstring:=sprintf('%s: row.%s', field, field)]
  fields[fclass=='integer', qstring:=sprintf('%s: toInt(row.%s)', field, field)]
  fields[fclass=='numeric', qstring:=sprintf('%s: toFloat(row.%s)', field, field)]
  # note that right now toBoolean in neo4j requires true/false string, so an easy way out (next line) doesn't work 
  # fields[fclass=='logical', qstring:=sprintf('%s: toBoolean(row.%s)', field, field)]
  fields[fclass=='logical', qstring:=sprintf('%s: (case row.%s when "1" then true else false end)', field, field)]
  paste(fields$qstring, collapse = ', ')
}

delete_last_added_exp <- function(failsafe=T, safe_time = 60*5){
  # safe time (in s) within which the last added experiment can be deleted with this function
  
  if (failsafe==T){
    
    query = sprintf('MATCH (n:Experiment) where exists(n.added_ts) and (%0.f - n.added_ts) < %s with n order by n.added_ts desc LIMIT 1  match (n)-[:PARTICIPATED_IN]-(s)-[*]-(b) detach delete b,s,n return count(n)', as.numeric(Sys.time()), safe_time)
    
    res <- cypher(graph, query)
    print(res)
    }
}
  
load_data_neo4j <- function(folder, config_file = 'import_conf.yaml'){
  conf <- read_vs_config(file.path(folder, config_file))
  data <- fread(file.path(folder, conf$Experiment$required$trials_file))
  
  
  # Check if all fields from config file are present and there are no duplicates
  
  all_fields <- c(unlist(conf$Subject$all),unlist(conf$Block$all),unlist(conf$Trial$all))
  
  if (length(missing_fields <- setdiff(all_fields, names(data)))>0){
    stop(sprintf('Fields "%s" described in configuration files are not found in the data file %s', paste(missing_fields, collapse = '", "'), conf$Experiment$required$trials_file))
  }
  
  if (exists('Stimulus', conf)|exists('stimuli_file',conf$Experiment$all)){
    if (!exists('stimuli_file',conf$Experiment$all))
      stop('The info about stimuli file is absent from the  Experiment section of config file')
    
    if (!exists('trial_id',conf$Trial$all)|!exists('trial_id',conf$Stimuli$all))
      stop('When adding stimuli, trial_id should be present in optional section of trial description and required section of stimuli description in the config file. Otherwise it is impossible to link stimuli with trials.')
    
    stimuli <- fread(file.path(folder, conf$Experiment$optional$stimuli_file))
    
    stimuli_fields <- unlist(conf$Stimulus$all)
    if (length(missing_fields <- setdiff(stimuli_fields, names(stimuli)))>0){
      stop(sprintf('Fields "%s" described in configuration files are not found in the stimuli file %s', paste(missing_fields, collapse = '", "'), conf$Experiment$required$stimuli_file))
    }
  }
  
  # Adding maintainer - using merge in case if it already exists
  query = sprintf('MERGE (author:Maintainer {name: "%s", email: "%s" })', conf$Maintainer$required$name, conf$Maintainer$required$email)
  cypher(graph, query)
  
  # Adding experiment
  conf$Experiment<-make_numbers_numbers(conf$Experiment)
  
  exp <- createNode(graph, 'Experiment', conf$Experiment$all)
  exp_id <- getID(exp)
  
  # Connect maintainer and experiment
  cypher(graph, sprintf('MATCH (m: Maintainer), (e: Experiment) WHERE m.email = "%s" AND ID(e) = %i CREATE (m)-[:ADDED]->(e)', conf$Maintainer$required$email, exp_id))
  
  # Subjects info - select unique subjects from datafile, write them to csv, load into db
  
  # Code for deleting subjects
  # query  = 'MATCH (e:Experiment), ((s:Subject)-[:PARTICIPATED_IN]-(e)) where ID(e) = exp_id_here DETACH DELETE s'
  
  setnames(data, unlist(conf$Subject$all), names(conf$Subject$all))
  subjects <- unique(data[,names(conf$Subject$all), with=F])
  subjects_import_string <- create_query_string(subjects)
  fwrite(subjects, paste0(neo4j_import,'subjects.csv'))
  query = sprintf('LOAD CSV WITH HEADERS FROM "file:///subjects.csv" AS row
                   MATCH (e:Experiment) WHERE ID(e) = %i
                   CREATE (subject:Subject {%s})-[:PARTICIPATED_IN]->(e) RETURN ID(subject)', exp_id, subjects_import_string)
  subj_ids<-cypher(graph, query)
  
  message(sprintf('Imported %i subjects', nrow(subj_ids)))
  
  

  # Blocks info - same routine as with subjects
  setnames(data, unlist(conf$Block$all), names(conf$Block$all))
  
  # If block_id is missing, create it as a unique ID for all block-related vars and subject ID.
  if (!exists('block_id',conf$Block$all)){
    data[,block_id:=.GRP, by = c(names(conf$Block$all), 'subj_id')]
    conf$Block$all$block_id <- 'block_id'
  }
  
  blocks <- unique(data[,c(names(conf$Block$all), 'subj_id'), with=F])
  
  # If block_n is missing, generate it sequentially within subject
  
  if (!exists('block_n',conf$Block$all)){
    conf$Block$all$block_n <- 'block_n'
    blocks[,block_n:=1:.N, by = subj_id]
  }
  
  fwrite(blocks, paste0(neo4j_import,'blocks.csv'))
  
  # Code for deleting blocks
  # cypher(graph, 'MATCH (b:Block) DETACH DELETE (b)')
  # cypher(graph, 'MATCH (b:DistrDistribution) DETACH DELETE (b)')
  
  # We match blocks with subjects using info from csv file to add session as a parameter for relationship. 
  # Then block ids are returned: our id from csv file and neo4j internal id.

  blocks_import_string<-create_query_string(blocks,list(block_n = 'integer', session = 'integer'))
  
  query = sprintf('LOAD CSV WITH HEADERS FROM "file:///blocks.csv" AS row
  CREATE (block:Block {%s})
  WITH block 
  MATCH (e:Experiment), (s:Subject)--(e) WHERE ID(e) = %i AND s.subj_id = block.subj_id CREATE (s)-[:DONE]->(block) RETURN block.block_id as block_id, ID(block) as block_internal_ids', blocks_import_string, exp_id)
  block_ids<-cypher(graph, query)
  
  message(sprintf('Imported %i blocks', nrow(block_ids)))
  
  # code for deleting trials
  # cypher(graph, 'MATCH (b:Trial) DETACH DELETE (b)')
  
  # Adding trials
  # Information about block IDs from neo4j is merged with data for trials import
  
  trials<-merge(data, block_ids, by='block_id')
  setnames(trials, unlist(conf$Trial$all), names(conf$Trial$all))
  
  # If trial_id or trial_n is missing, generate it
  if (!exists('trial_id',conf$Trial$all)){
    conf$Trial$all$trial_id <- 'trial_id'
    trials[,trial_id:=1:.N]
  }
  
  if (!exists('trial_n',conf$Trial$all)){
    conf$Trial$all$trial_n <- 'trial_n'
    trials[,trial_n:=1:.N, by = block_id]
  }
  
  trials <- trials[,c(names(conf$Trial$all),'block_internal_ids'), with=F]
  
  fwrite(trials, paste0(neo4j_import,'trials.csv'))
  trials_import_string <- create_query_string(trials[,!c('block_internal_ids','trial_id'), with=F])
  
  # Load from csv, link to blocks by IDs, return trial IDs
  query = sprintf('LOAD CSV WITH HEADERS FROM "file:///trials.csv" AS row
           CREATE (trial:Trial {%s})
           WITH trial, row
           MATCH (b:Block) WHERE toInt(row.block_internal_ids) = ID(b) CREATE (b)-[:CONTAINS]->(trial) RETURN ID(trial) as trial_internal_ids' , trials_import_string)
  
  trial_ids <- cypher(graph, query)
  trials$trial_internal_ids<-trial_ids$trial_internal_ids
  
  message(sprintf('Imported %i trials', nrow(trial_ids)))

  # Code to delete stimuli
  # cypher(graph, 'MATCH (b:Stimulus) DETACH DELETE (b)')
  if (exists('Stimulus', conf)){
    # Adding stimuli
    setnames(stimuli,unlist(conf$Stimulus$all), names(conf$Stimulus$all))
    stimuli <- merge(stimuli, trials[,.(trial_id, trial_internal_ids)], by='trial_id')
    stimuli <- stimuli[,c(names(conf$Stimulus$all),'trial_internal_ids'), with=F]
    
    fwrite(stimuli, paste0(neo4j_import,'stimuli.csv'))
    stimuli_import_string <- create_query_string(stimuli[,!c('trial_internal_ids','trial_id'), with=F])
    
    
    query = sprintf('USING PERIODIC COMMIT 5000
             LOAD CSV WITH HEADERS FROM "file:///stimuli.csv" AS row
             CREATE (stim:Stimulus:Distractor {%s})
             WITH stim, row
             MATCH (t:Trial) WHERE toInt(row.trial_internal_ids) = ID(t) CREATE (t)-[:CONTAINS]->(stim) RETURN count(stim)' , stimuli_import_string)
    stim_count <- cypher(graph, query)
    
    message(sprintf('Imported %i stimuli', stim_count[1,1]))
    
    cypher(graph, sprintf('MATCH (e: Experiment)--(:Subject)--(:Block)--(:Trial)--(s: Stimulus {is_target: TRUE}) WHERE ID(e) = %i SET s:Target REMOVE s:Distractor, s.is_target RETURN count(s)', exp_id))
    while (1){
      distr_count<-cypher(graph, sprintf('MATCH (s:Stimulus:Distractor) where exists(s.is_target) with s LIMIT 50000 SET s.is_target = NULL RETURN count(s)', exp_id))
      message(sprintf('Marking distractors: N = %s', distr_count))
      if (as.numeric(distr_count)==0) break;
    }
  }
  message(sprintf('Finished importing using %s', file.path(folder, config_file)))
}

