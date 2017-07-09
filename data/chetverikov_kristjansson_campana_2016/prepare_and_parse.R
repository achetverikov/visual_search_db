library(yaml)
library(data.table)
library(stringr)
library(tools)
source('import_data/parse_config_for_neo4j.R')

data_dir <- 'data/chetverikov_kristjansson_campana_2016/'
data_files <- list.files(data_dir,pattern='exp.*csv', full.names = T)

displays<-fread(paste0(data_dir, 'displays.csv'))

for (fname in data_files){
  cat(paste(fname,"\n"))
  data<-fread(fname)
  
  full_expname <- paste0('Experiment ', str_extract(fname,'\\d+[^./]*(?=\\.)'))
  
  if (grepl('exp[12]', fname)){
    equipment <- list(display_name='dell_vostro', os_name='Windows 8', software='PsychoPy')
  } else if (grepl('exp[34]', fname)){
    equipment <- list(display_name='compaq_S720', os_name='Windows 7', software='PsychoPy 1.82.01')
  }
  equipment<-modifyList(equipment, as.list(unlist(displays[name==equipment$display_name,!"name"])))
  equipment$full_name <- full_expname
  
  equipment$stimuli_file <- paste0(file_path_sans_ext(basename(fname)),'_stimuli.csv')
  equipment$trials_file <- paste0(file_path_sans_ext(basename(fname)),'_trials.csv')
  
  generic_config <- yaml.load_file(file.path(data_dir, 'import_conf.yaml'))
  
  eq_required <- intersect(names(generic_config$Experiment$required), names(equipment))
  eq_optional <- intersect(names(generic_config$Experiment$optional), names(equipment))
  
  generic_config$Experiment$required <- modifyList(generic_config$Experiment$required, equipment[eq_required])
  generic_config$Experiment$optional <- modifyList(generic_config$Experiment$optional, equipment[eq_optional])
  
  
  data[,blockId:=.GRP, by=.(subjectId,block, session,  dtype, dsd)]
  data[,tid:=1:.N]
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

  fwrite(d_ori[,.(tid, is_target, ori=round(value), pos_x, pos_y)], file.path(data_dir, equipment$stimuli_file))
  fwrite(data, file.path(data_dir, equipment$trials_file))
  current_yaml_path <- paste0(file_path_sans_ext(fname),'_config.yaml')
  sink(current_yaml_path)
  cat(as.yaml(generic_config))
  sink()
  load_data_neo4j(data_dir, basename(current_yaml_path))
  }