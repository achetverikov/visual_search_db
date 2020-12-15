library(readxl)
grid_data <- fread('data/buetti_xu_lleras_2019/buetti_2019_grid.csv')

stim_pars <- read_excel('data/buetti_xu_lleras_2019/OSF_originaldata_corrected.xlsx', 1,'F2:H32')
setDT(stim_pars)
names(stim_pars) <- c('exp','type','descr')
stim_pars[, exp := exp[nafill(replace(.I, is.na(exp), NA), "locf")]]
stim_pars[,exp:=str_replace(exp,'Experiment ','')]

stim_pars<-rbindlist(list(stim_pars, 
                        list('1A','4','cyan'),
                        list('3A','4','red'),
                        list('1B','4','semicircle'),
                        list('3B','4','triangle'),
                        list('2A','4','cyan semicircle'),
                        list('2B','4','cyan semicircle'),
                        list('2C','4','cyan semicircle'),
                        list('4A','4','red triangle'),
                        list('4B','4','red triangle'),
                        list('4C','4','red triangle')
                        ))
stim_pars[grepl('blue',descr),color:='Lab 29,68,−111']
stim_pars[grepl('orange',descr),color:='Lab 65,52,73']
stim_pars[grepl('yellow',descr),color:='Lab 98,-16,-93']
stim_pars[grepl('red',descr),color:='Lab 54,81,70']
stim_pars[grepl('cyan',descr),color:='Lab 69,-28,-35']
stim_pars[is.na(color),color:='Lab 91,0,0']
stim_pars[,shape:=str_extract(descr,'diamond|semicircle|triangle|circle')]
stim_pars[exp=='1A',shape:='semicircle']
stim_pars[exp=='3A',shape:='triangle']
stim_pars[,type:=as.numeric(type)]

exp_ids <- str_replace(unique(stim_pars$exp),'Experiment ','')

for (x in exp_ids){
  cur_stim_pars <- stim_pars[exp==x]
  data <- data.table(rbind(read_excel('data/buetti_xu_lleras_2019/OSF_originaldata_corrected.xlsx',sprintf('Experiment%s(included)', x)),
                           read_excel('data/buetti_xu_lleras_2019/OSF_originaldata_corrected.xlsx',sprintf('Experiment%s(excluded)', x))))
  
  data[,trial_id:=1:.N]
  
  stim<-melt(data,measure.vars = patterns('loc\\d+'))
  stim<-stim[value!=0]
  
  stim[,loc_id:=as.numeric(str_extract(variable,'\\d+'))]
  stim <- merge(stim, grid_data, by= 'loc_id')
  stim <- merge(stim, cur_stim_pars, by.x='value',by.y='type', all.x=T)
  stim[,is_target:=ifelse(value==4,1,0)]
  data[Error==3, Error:=2]
  data[,block_n:=1]
  
  fwrite(data[,.(trial_id, Subject, block_n, Trial, set_size = numd+1, correctResponse=tid, resp, acc=1-Error, RT)], file = sprintf('data/buetti_xu_lleras_2019/exp%s_parsed.csv', x))
  fwrite(stim[,.(trial_id, is_target, color, shape, posx_deg, posy_deg)], file = sprintf('data/buetti_xu_lleras_2019/exp%s_stim.csv', x))
  print(x)
  print(data[,lengthu(Subject)])
  config <- yaml.load(gsub('EID',x,readLines('data/buetti_xu_lleras_2019/Buetti_config_template.yml')))
  
  config$Meta$Sample$optional$sample_size <- lengthu(data$Subject)
  if (cur_stim_pars[,lengthu(shape)]>1 & cur_stim_pars[,lengthu(color)]>1) {
    config$Dataset$Experiment$optional$task <- 'compound feature'
  }  else config$Dataset$Experiment$optional$task <- 'feature'
  if (cur_stim_pars[,lengthu(shape)]>1 & cur_stim_pars[,lengthu(color)]>1) {
    config$Dataset$Experiment$optional$guiding_attribute <- 'color and shape'
  }  else if (cur_stim_pars[,lengthu(shape)]>1) {
    config$Dataset$Experiment$optional$guiding_attribute <- 'shape'
  } else config$Dataset$Experiment$optional$guiding_attribute <- 'color'
  
  config$Dataset$Experiment$optional$target_description <- cur_stim_pars[type==4, paste0(descr, ' (',color,') ', shape)]
  write_yaml(config, sprintf('data/buetti_xu_lleras_2019/exp%s_config.yml',x))
  read_vs_config(sprintf('data/buetti_xu_lleras_2019/exp%s_config.yml',x))
  load_data_neo4j('data/buetti_xu_lleras_2019',sprintf('exp%s_config.yml',x))
}
