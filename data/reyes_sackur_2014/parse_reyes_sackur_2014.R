library(Hmisc)
exp_list <- c(1,3,4,5)
for (exp_n in c(4,5)) {
  data <- fread(sprintf('data/reyes_sackur_2014/data%s.txt', exp_n), na.strings = 'None')

  data[,training:=as.numeric(grepl('^(pT|t)',trialType))]
  data[,.N,by=.(trialType, training, targType)]
  data[,task:=ifelse(targType=='X','X among T','L among T')]
  data[,present:=as.numeric(present)]
  data[,trialId:=1:.N]
  if (exp_n>=4) data[,PostTest:=NULL]
  fwrite(data, file=sprintf('data/reyes_sackur_2014/data%s_parsed.csv', exp_n))
  if ('couleur' %nin% names(data)) data$couleur = NA
  fwrite(data[,.(trialId, targType, couleur, is_target=1)], file=sprintf('data/reyes_sackur_2014/stim%s_parsed.csv', exp_n))
  #read_vs_config(sprintf('data/reyes_sackur_2014/reyes_sackur_2014_data%s.yaml', exp_n))
  load_data_neo4j('data/reyes_sackur_2014',sprintf('reyes_sackur_2014_data%s.yaml', exp_n))
}

