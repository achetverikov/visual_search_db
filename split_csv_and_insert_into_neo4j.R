library(RNeo4j)
library(stringr)
library(data.table)
rm(list=ls())

graph = startGraph("http://localhost:7474/db/data/",username = 'neo4j', password = 'l00sers')
data_files <- list.files('data',pattern='exp.*', full.names = T)
neo4j_import = 'C:/Users/Notandi/Documents/Neo4j/default.graphdb/import/'
options(warn=2)

addConstraint(graph, "Author", "email")
addConstraint(graph, "Experiment", "name")
addConstraint(graph, "Display", "name")
addConstraint(graph, "DistrDistribution", "pdf")
# createNode(graph, 'Target')
# createNode(graph, 'Distractor')
# createNode(graph, 'Orientation')
# createNode(graph, 'Length')
# createNode(graph, 'Color')
# createNode(graph, 'Position')

author<-data.table(name = 'Andrey Chetverikov', email = 'andrey@hi.is')

query = sprintf('MERGE (author:Author {name: "%s", email: "%s" })', author$name, author$email)
cypher(graph, query)

displays<-fread('data/displays.csv')
fwrite(displays, paste0(neo4j_import,'displays.csv'))

query = paste0('LOAD CSV WITH HEADERS FROM "file:///displays.csv" AS row
MERGE (display:Display {name: row.name, full_name: row.display_name, display_size_x: toInt(row.display_size_x), display_size_y: toInt(row.display_size_y), display_res_x: toInt(row.display_res_x), display_res_y: toInt(row.display_res_y)})')
cypher(graph, query)

for (fname in data_files){
  cat(paste(fname,"\n"))
  full_expname <- paste0('Experiment ', str_extract(fname,'\\d+[^.]*'))
  data<-fread(fname)
  
  if (grepl('exp[12]', fname)){
    equipment <- list(display_name='dell_vostro', os_name='Windows 8', software='PsychoPy', response_device='keyboard')
  } else if (grepl('exp[34]', fname)){
    equipment <- list(display_name='compaq_S720', os_name='Windows 7', software='PsychoPy 1.82.01', response_device='keyboard')

  }
  exp_info <- list(name = data$expName[1], full_name = full_expname, task = "outlier", data_url = "https://osf.io/h4epz/", display_arr = 'jittered_grid', exp_date=as.numeric(as.POSIXct('2015-06-01')), citation_info = 'Chetverikov, A., Campana, G., Kristjansson, Á. (2016). Building ensemble representations: How the shape of preceding distractor distributions affects visual search. Cognition, 153, 196–210. http://doi.org/10.1016/j.cognition.2016.04.018')
  createNode(graph, 'Experiment', append(exp_info, equipment))
  
  subjects <- unique(data[,c('subjectId','subjectAge', 'subjectGender'), with=F], by=c('subjectId','subjectAge', 'subjectGender'))
  fwrite(subjects, paste0(neo4j_import,'subjects.csv'))
data
  data[,blockId:=.GRP, by=.(subjectId,block, session,  dtype, dsd)]
  
  query = sprintf(paste0('LOAD CSV WITH HEADERS FROM "file:///subjects.csv" AS row
MATCH (e:Experiment {name:"%s"})
CREATE (subject:Subject {id: toInt(row.subjectId), age: toInt(row.subjectAge), gender: row.subjectGender})-[:PARTICIPATED_IN]->(e) '), data$expName[1])
  
  cypher(graph, query)
  #query  = 'MATCH (e:Experiment {name:"distr_stats"}) MATCH ((s:Subject)-[:PARTICIPATED_IN]-(e)) DETACH DELETE s'
  blocks <- unique(data[,.(subjectId, blockId, block, session, dtype, dsd, distrMean)])
  fwrite(blocks, paste0(neo4j_import,'blocks.csv'))
  
  #cypher(graph, 'MATCH (b:Block) DETACH DELETE (b)')
  #cypher(graph, 'MATCH (b:DistrDistribution) DETACH DELETE (b)')
  
  query = sprintf('LOAD CSV WITH HEADERS FROM "file:///blocks.csv" AS row
  CREATE (block:Block {id: toInt(row.blockId), subj: toInt(row.subjectId)})
  MERGE (dd:DistrDistribution {pdf: row.dtype})
  CREATE (dd)<-[:HAS {mean:toInt(row.distrMean), sd:toInt(row.dsd)}]-(block)
  WITH block, row
  MATCH (e:Experiment {name:"%s"}) 
  MATCH (s:Subject)--(e) WHERE s.id = block.subj CREATE (s)-[:DONE {session: row.session}]->(block) RETURN toInt(block.id) as blockId, ID(block) as block_id', data$expName[1])
  block_ids <- cypher(graph, query)
  trials<-merge(data, block_ids, by='blockId')
  
  fwrite(trials[,.(subjectId, blockId, block_id, trial = as.numeric(trial)+1, correctAnswer, answer, rt=round(rt), correct)], paste0(neo4j_import,'trials.csv'))
  
  #cypher(graph, 'MATCH (b:Trial) DETACH DELETE (b)')
  query = ('LOAD CSV WITH HEADERS FROM "file:///trials.csv" AS row
  CREATE (trial:Trial {id: row.trial, rt: toInt(row.rt), correct: toBoolean(row.correct), answer: row.answer, correctAnswer: row.correctAnswer})
  WITH trial, row
  MATCH (b:Block) WHERE toInt(row.block_id) = ID(b) CREATE (b)-[:CONTAINS]->(trial) RETURN trial.rt as rt, ID(trial) as trial_id' )
  
  trial_ids <- cypher(graph, query)
  
  data$trial_id<-trial_ids$trial_id
  
  print(cypher(graph,'MATCH (t:Trial)-[:CONTAINS]-(b:Block)-[dprop:HAS]-(dd:DistrDistribution) WITH dprop.sd as DSD, ID(b) as id, avg(t.rt) as rt RETURN DSD, avg(rt)'))
  
  
  if (grepl('exp1', fname)){
    d_ori_cols<-paste0('d_ori_',0:35)
    data[,(d_ori_cols):=NA_integer_]
  }
  
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
