for (x in list.files('data/nowakowska_clarke_hunt_2017/', '.txt', full.names = T)){
  data <- fread(x, na.strings = 'x')
  setnames(data,'var','distractor_range', skip_absent = T)  
  setnames(data,'variability','distractor_range', skip_absent = T)
  if ('RT' %nin% names(data)) data$RT <- NA
  if ('distractor_range' %in% names(data)) {
    data[,distractor_range:=round(180/distractor_range)]
    data[,distractor_min:=-45-distractor_range/2]
    data[,distractor_max:=-45+distractor_range/2]
  }
  data[,RT:=RT*1000]
  data[,block_no:=1]
  exp_name <- dplyr::case_when(grepl('E1',x)~'exp1', grepl('E2',x)~'exp2', T ~ 'pilot')
  fwrite(data, paste0('data/nowakowska_clarke_hunt_2017/',exp_name,'_parsed.csv'))
}
