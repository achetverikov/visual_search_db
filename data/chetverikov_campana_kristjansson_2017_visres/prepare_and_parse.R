# This files is specifically for the experiments described in Chetverikov, Kristjansson, Campana, 2017
# Splits experiment data into trials & stimuli, writes configs

library(yaml)
library(data.table)
library(stringr)
library(tools)
source('import_data/parse_config_for_neo4j.R')

data_dir <- './data/chetverikov_campana_kristjansson_2017_visres/'
data_files <- list.files(data_dir,pattern='exp\\d(\\w?)\\.csv', full.names = T)

displays<-fread(paste0(data_dir, 'displays.csv'))

for (fname in data_files){
  cat(paste(fname,"\n"))
  data<-fread(fname)
  
  full_expname <- paste0('CCK_2017_visres_exp', str_extract(fname,'\\d+[^./]*(?=\\.)'))
  
  equipment <- list(display_name='iiyama')
  if (grepl('exp1', fname)){
    equipment$exp_date <- '2016-08'
  } else if (grepl('exp2', fname)) {
    equipment$exp_date <- '2017-01 to 2017-03'
  }
  
  equipment<-modifyList(equipment, as.list(unlist(displays[name==equipment$display_name,!"name"])))

  
  generic_config <- yaml.load_file(file.path(data_dir, 'import_conf.yaml_template'))
  # base_config <- yaml.load_file(file.path(data_dir, 'import_conf.yaml_template'))
  
  eq_required <- intersect(names(generic_config$Dataset$Experiment$required), names(equipment))
  eq_optional <- intersect(names(generic_config$Dataset$Experiment$optional), names(equipment))
  
  generic_config$Dataset$Experiment$required <- modifyList(generic_config$Dataset$Experiment$required, equipment[eq_required])
  generic_config$Dataset$Experiment$optional <- modifyList(generic_config$Dataset$Experiment$optional, equipment[eq_optional])
  
  generic_config$Meta$Description$optional$stimuli_file <- paste0(file_path_sans_ext(basename(fname)),'_stimuli.csv')
  generic_config$Meta$Description$required$trials_file <- paste0(file_path_sans_ext(basename(fname)),'_trials.csv')
  generic_config$Meta$Description$required$full_name <- full_expname
  
  data[,blockId:=.GRP, by=.(subjectId,block, session,  dtype, dsd)]
  data[,tid:=1:.N]
  
  # this just transform the data file and creates neccessary variables
  d_ori<-melt(data, measure.vars = patterns('d_ori|stim_pos'))
  d_ori[,stim_i:=as.numeric(str_extract(variable,'\\d+'))]
  d_ori[,var_name:=str_replace(str_extract(variable, '(.*)(?=_\\d+)'),'stim_|d_',''), by = variable]
  d_ori[,is_target:=as.numeric(stim_i==targetPos)]
  # d_ori[,row:=stim_i%%6]
  # d_ori[,col:=stim_i%/%6]
  # 
  # d_ori[,value:=as.integer(round(value))]
  d_ori[is_target==1&var_name=='ori', value:=targetOri]
  # 
  
  fwrite(  dcast(d_ori, tid+stim_i+is_target~var_name, value.var = 'value')[,.(tid, is_target, ori=round(ori), pos_x, pos_y)][!is.na(pos_x)], file.path(data_dir, generic_config$Meta$Description$optional$stimuli_file))
  fwrite(data[,.SD,.SDcols = !patterns('d_ori|stim_pos')], file.path(data_dir, generic_config$Meta$Description$required$trials_file))
  current_yaml_path <- paste0(file_path_sans_ext(fname),'_config.yaml')
  sink(current_yaml_path)
  cat(as.yaml(generic_config))
  sink()
  load_data_neo4j(data_dir, basename(current_yaml_path))
}
