# This code is for data import from the experiments in Chetverikov et al. (2016) ensemble statistics paper (exp1, 2, 3A-3C, and 4.csv in data folder). Typical approach is dump to csv then import from csv because it's faster. 

library(RNeo4j)
library(stringr)
library(data.table)
rm(list=ls())

data_dir <- 'data/'

# Turn on stopping on warnings in the loop
options(warn=2)

# Checking if constraints exist and adding them if not

existing_constraints <- cypher(graph, 'CALL db.indexes()')
setDT(existing_constraints)
if (nrow(existing_constraints)==0||existing_constraints[grepl('Author',description),.N]==0)
  addConstraint(graph, "Author", "email")
if (nrow(existing_constraints)==0||existing_constraints[grepl('Experiment',description),.N]==0)
  addConstraint(graph, "Experiment", "name")
if (nrow(existing_constraints)==0||existing_constraints[grepl('Display',description),.N]==0)
  addConstraint(graph, "Display", "name")
if (nrow(existing_constraints)==0||existing_constraints[grepl('DistrDistribution',description),.N]==0)
  addConstraint(graph, "DistrDistribution", "pdf")

# I had an idea to use properties as nodes and to code their values in edges, but it seem to be problematic with large DB

# createNode(graph, 'Target')
# createNode(graph, 'Distractor')
# createNode(graph, 'Orientation')
# createNode(graph, 'Length')
# createNode(graph, 'Color')
# createNode(graph, 'Position')

# Adding author (more properly, it should be maintainer)

author<-data.table(name = 'Andrey Chetverikov', email = 'andrey@hi.is')

query = sprintf('MERGE (author:Author {name: "%s", email: "%s" })', author$name, author$email)
cypher(graph, query)

# Adding displays
# Display info is in displays.csv in data folder

displays<-fread(paste0(data_dir, 'displays.csv'))
fwrite(displays, paste0(neo4j_import,'displays.csv'))

query = paste0('LOAD CSV WITH HEADERS FROM "file:///displays.csv" AS row
MERGE (display:Display {name: row.name, full_name: row.display_name, display_size_x: toInt(row.display_size_x), display_size_y: toInt(row.display_size_y), display_res_x: toInt(row.display_res_x), display_res_y: toInt(row.display_res_y)})')
cypher(graph, query)

# Looping through experiment files

for (fname in data_files){
  cat(paste(fname,"\n"))
  full_expname <- paste0('Experiment ', str_extract(fname,'\\d+[^.]*'))
  data<-fread(fname)
  
  # blockId - useful later for importing blocks
  data[,blockId:=.GRP, by=.(subjectId,block, session,  dtype, dsd)]
  
  # Experimental info - hardcoded as of right now
  
  if (grepl('exp[12]', fname)){
    equipment <- list(display_name='dell_vostro', os_name='Windows 8', software='PsychoPy', response_device='keyboard')
  } else if (grepl('exp[34]', fname)){
    equipment <- list(display_name='compaq_S720', os_name='Windows 7', software='PsychoPy 1.82.01', response_device='keyboard')
  }

  exp_info <- list(name = data$expName[1], full_name = full_expname, task = "outlier", data_url = "https://osf.io/h4epz/", display_arr = 'jittered_grid', exp_date=as.numeric(as.POSIXct('2015-06-01')), citation_info = 'Chetverikov, A., Campana, G., Kristjansson, Á. (2016). Building ensemble representations: How the shape of preceding distractor distributions affects visual search. Cognition, 153, 196–210. http://doi.org/10.1016/j.cognition.2016.04.018')
  createNode(graph, 'Experiment', append(exp_info, equipment))
  
  # Subjects info - select unique subjects from datafile, write them to csv, load into db
  subjects <- unique(data[,c('subjectId','subjectAge', 'subjectGender'), with=F], by=c('subjectId','subjectAge', 'subjectGender'))
  fwrite(subjects, paste0(neo4j_import,'subjects.csv'))

  # Note that experiment is matched by name
  query = sprintf(paste0('LOAD CSV WITH HEADERS FROM "file:///subjects.csv" AS row
MATCH (e:Experiment {name:"%s"})
CREATE (subject:Subject {id: toInt(row.subjectId), age: toInt(row.subjectAge), gender: row.subjectGender})-[:PARTICIPATED_IN]->(e) '), data$expName[1])
  
  cypher(graph, query)
  
  # Code for deleting subjects
  # query  = 'MATCH (e:Experiment {name:"distr_stats"}) MATCH ((s:Subject)-[:PARTICIPATED_IN]-(e)) DETACH DELETE s'
  
  # Blocks info - same routine as with subjects
  blocks <- unique(data[,.(subjectId, blockId, block, session, dtype, dsd, distrMean)])
  fwrite(blocks, paste0(neo4j_import,'blocks.csv'))
  
  # Code for deleting blocks
  # cypher(graph, 'MATCH (b:Block) DETACH DELETE (b)')
  # cypher(graph, 'MATCH (b:DistrDistribution) DETACH DELETE (b)')
  
  # The query code adds block info, then creates "distribution" node if it does not exists, and connects it to the block. Not sure if a good thing or not. On one hand, it simplifies search, on the other hand we need to connect each block to that distribution. 
  # Then we match blocks with subjects using info from csv file to add session as a parameter for relationship. 
  # Then block ids are returned: our id from csv file and neo4j internal id.
  
  query = sprintf('LOAD CSV WITH HEADERS FROM "file:///blocks.csv" AS row
  CREATE (block:Block {id: toInt(row.blockId), subj: toInt(row.subjectId)})
  MERGE (dd:DistrDistribution {pdf: row.dtype})
  CREATE (dd)<-[:HAS {mean:toInt(row.distrMean), sd:toInt(row.dsd)}]-(block)
  WITH block, row
  MATCH (e:Experiment {name:"%s"}) 
  MATCH (s:Subject)--(e) WHERE s.id = block.subj CREATE (s)-[:DONE {session: row.session}]->(block) RETURN toInt(block.id) as blockId, ID(block) as block_id', data$expName[1])
  block_ids <- cypher(graph, query)
  
  # code for deleting trials
  # cypher(graph, 'MATCH (b:Trial) DETACH DELETE (b)')
  
  # Adding trials
  # Information about block IDs from neo4j is merged with data for trials import
  trials<-merge(data, block_ids, by='blockId')
  
  fwrite(trials[,.(subjectId, blockId, block_id, trial = as.numeric(trial)+1, correctAnswer, answer, rt=round(rt), correct)], paste0(neo4j_import,'trials.csv'))
  
  # Load from csv, link to blocks by IDs, return trial IDs
  query = ('LOAD CSV WITH HEADERS FROM "file:///trials.csv" AS row
  CREATE (trial:Trial {id: row.trial, rt: toInt(row.rt), correct: toBoolean(row.correct), answer: row.answer, correctAnswer: row.correctAnswer})
  WITH trial, row
  MATCH (b:Block) WHERE toInt(row.block_id) = ID(b) CREATE (b)-[:CONTAINS]->(trial) RETURN trial.rt as rt, ID(trial) as trial_id' )
  
  trial_ids <- cypher(graph, query)
  data$trial_id<-trial_ids$trial_id
  
  # Just a sample query to get average rt per block by block distribution SD
  
  print(cypher(graph,'MATCH (t:Trial)-[:CONTAINS]-(b:Block)-[dprop:HAS]-(dd:DistrDistribution) WITH dprop.sd as DSD, ID(b) as id, avg(t.rt) as rt RETURN DSD, avg(rt)'))
  
  # Now the stimuli
  
  # For experiment 1 stimuli columns are missing, but we still can add some data about positions and target orientation
  if (grepl('exp1', fname)){
    d_ori_cols<-paste0('d_ori_',0:35)
    data[,(d_ori_cols):=NA_integer_]
  }
  
  # this just transform the data file and creates neccessary variables
  d_ori<-melt(data, measure.vars = patterns('d_ori'))
  d_ori[,stim_i:=as.numeric(str_extract(variable,'\\d+'))]
  d_ori[,is_target:=as.numeric(stim_i==targetPos)]
  
  d_ori[,row:=stim_i%%6]
  d_ori[,col:=stim_i%/%6]
  
  d_ori[,pos_y:=row*3.2-8]
  d_ori[,pos_x:=col*3.2-8]
  d_ori[,value:=as.integer(round(value))]
  d_ori[is_target==1, value:=targetOri]
  
  cat("--processing stimuli--\n")
  fwrite(d_ori[,.(trial_id, is_target, ori=round(value), pos_x, pos_y)], paste0(neo4j_import,'stimuli.csv'))
  
  # commented out: initial idea was to keep properties names as nodes and code properties in relationships between stimuli and property name
  # didn't work out 602MB
  # CREATE (stim:Stimulus {is_target: toBoolean(row.is_target)})
  # CREATE (stim)-[:AT{x:row.pos_x, y:row.pos_y}]->(:Position)
  # CREATE (stim)-[:HAS{value:row.ori}]->(:Orientation)
  # 
  #cypher(graph, 'MATCH (b:Stimulus) DETACH DELETE (b)')
  query = ('USING PERIODIC COMMIT 5000
  LOAD CSV WITH HEADERS FROM "file:///stimuli.csv" AS row
  CREATE (stim:Stimulus {isTarget: toBoolean(row.is_target), posX:toFloat(row.pos_x), posY:toFloat(row.pos_y), ori:toInt(row.ori)})
  WITH stim, row
  MATCH (t:Trial) WHERE toInt(row.trial_id) = ID(t) CREATE (t)-[:CONTAINS]->(stim)' )
  cypher(graph, query)
}

# finally, join author and displays with experiments
query = paste0('MATCH (e:Experiment), (d:Display), (a:Author{email:"',author$email,'"}) WHERE e.display_name = d.name 
               CREATE (a)-[:ADDED]->(e)-[:RUN_ON]->(d)')

cypher(graph, query)
