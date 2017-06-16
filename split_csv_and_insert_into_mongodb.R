library(stringr)
library(data.table)
rm(list=ls())

data_files <- list.files('data',pattern='exp.*', full.names = T)
source('mongo_connect.R')
source('mongo_drop_all.R')

author<-data.table(name = 'Andrey Chetverikov', email = 'andrey@hi.is')

# Check if author exists

author_id <- m_authors$find(paste0('{"email" : "',author$email,'"}'),fields = '{"_id":1}')$'_id'

if (is.null(author_id)){
  m_authors$insert(author[,'_id':=getNextSequence('authors')])
  author_id <- author$'_id'
}

displays<-fread('data/displays.csv')

for (fname in data_files){
  print(fname)
  data<-fread(fname)
  
  if (grepl('exp[12]', fname)){
    equipment <- cbind(displays[name=='dell_vostro'], data.table(os_name='Windows 8', software='PsychoPy', response_device='laptop keyboard'))
  } else if (grepl('exp[34]', fname)){
    equipment <- cbind(displays[name=='compaq_S720'], data.table(os_name='Windows 7', software='PsychoPy 1.82.01', response_device='keyboard'))
  }
  eq_id <- m_equipment$find(paste0('{"name" : "',equipment$name[1],'"}'),fields = '{"_id":1}')$'_id'
  
  if (is.null(eq_id)){
    m_equipment$insert(equipment[,'_id':=getNextSequence('equipment')])
    eq_id <- equipment$'_id'
  }
  
  
  exp_info <- data.table(exp_name = data$expName[1], task = "outlier", data_url = "https://osf.io/h4epz/", display_arr = 'jittered_grid', exp_date=as.numeric(as.POSIXct('2015-06-01')), author_id=author_id, equip_id = eq_id, citation_info = 'Chetverikov, A., Campana, G., Kristjansson, Á. (2016). Building ensemble representations: How the shape of preceding distractor distributions affects visual search. Cognition, 153, 196–210. http://doi.org/10.1016/j.cognition.2016.04.018')
  
  m_exp$insert(exp_info[,'_id':=getNextSequence('exps')])
  
  subjects <- unique(data[,c('subjectId','subjectAge', 'subjectGender'), with=F], by=c('subjectId','subjectAge', 'subjectGender'))
  subjects[,exp_id:=exp_info$`_id`]
  
  
  m_subj$insert(subjects[,'_id':=getNextSequence('subjects',.N)][,.(`_id`, subjectAge, subjectGender)])
  
  data[,blockId:=.GRP, by=.(subjectId,block, session, dtype, dsd)]
  
  blocks <- unique(data[,.(subjectId,blockId,block, session, dtype, dsd, distrMean)])
  blocks <- merge(blocks, subjects, by='subjectId')
  blocks[,subj_id:=`_id`]
  
  m_blocks$insert(blocks[,'_id':=getNextSequence('blocks',.N)][,.(`_id`, subj_id, session, rg_distr_pdf=dtype, rg_distr_sd=dsd,  rg_distr_mean=distrMean)])
  blocks[,block_id:=`_id`]
  
  data<-merge(data, blocks[,.(blockId, block_id)], by='blockId')
  
  
  m_trials$insert(data[,'_id':=getNextSequence('trials',.N)][,.(`_id`, block_id, correct_answer=correctAnswer, answer, rt=round(rt), correct)])
  
  setnames(data, '_id', 'trial_id')
  
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
  d_ori[is_target==1, value:=targetOri]
  
  m_stims$insert(d_ori[,'_id':=getNextSequence('stims',.N) ][,.(`_id`, trial_id, is_target, ori = round(value), pos_x, pos_y)])
  
}

m_blocks$index(add = "exp_id")
m_trials$index(add = "block_id")
mongolitedt::bind_mongolitedt(m_blocks)

m_blocks$aggregate('[{"$lookup": {"from": "trials", "localField": "_id", "foreignField": "block_id", "as": "trials_in_block"}}]')

m_exp$aggregate('[{"$lookup": {"from": "equipment", "localField": "equip_id", "foreignField": "_id", "as": "equipment"}}]')


