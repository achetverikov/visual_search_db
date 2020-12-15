# from the readme
# distractorColors= The color or identify of the distractors present on a given display 
# RT = The reaction time on the display (in ms)
# keyResponse= The button the subject pressed [0= right, 1=left]
# Error= Records whether the subject made and error [0=no error, 1=error]
# Location(1:36)=Records the identity of the object at that location. 
# 	1= target
# 	2= orange diamonds and blue circle lure objects
# 	3= yellow triangle lure objects
# from the Matlab code:
# if DATA(itrial).dcolors==1
#     Screen('DrawTexture',window,og,[],[tempx tempy tempx+30 tempy+30]);
# elseif DATA(itrial).dcolors==2
#     Screen('DrawTexture',window,bl,[],[tempx tempy tempx+30 tempy+30]);
# so if distractorColors == 1 and loc_i == 2, orange diamonds were presented
# so if distractorColors == 2 and loc_i == 2, blue circles were presented
# also from the Matlab code 
# dcolors=[0,1,2,3];   %noise colors (0=no noise distractors,1=orange, 2=blue, 3=yellow)
library(readxl)
grid_data <- fread('data/buetti_et_al_2016/buetti_grid.csv')
for (x in c('1A', '1B','2','3A','3B','3C','3D','4')[4:7]){
  if (x!='3A'){
  data <- data.table(rbind(read_excel(sprintf('data/buetti_et_al_2016/Experiment %s_Included.xlsx', x)),
                           read_excel(sprintf('data/buetti_et_al_2016/Experiment %s_Excluded.xlsx', x))))
  } else {
      data <- data.table(read_excel(sprintf('data/buetti_et_al_2016/Experiment %s_Included.xlsx', x)))
  }
  setnames(data, 'dcolors','distractorColors',skip_absent = T)
  setnames(data, 'numd','numDistractors',skip_absent = T)
  setnames(data, 'Candidate Number','numDistractors',skip_absent = T)
  setnames(data, 'Number of Lures','numLures',skip_absent = T)
  setnames(data, 'Lure Number','numLures',skip_absent = T)
  setnames(data, 'tid','Target ID',skip_absent = T)
  setnames(data, 'resp','keyResponse',skip_absent = T)
  if (x%in%c('1A','1B')){
    data[,distrColor:=car::recode(distractorColors,'0=NA;1="orange";2="blue";3="yellow"')]
    data[,distrShape:=car::recode(distractorColors,'0=NA;1="diamond";2="circle";3="triangle"')]
  } 
  data[,trial_id:=1:.N]
  
  stim<-melt(data,measure.vars = patterns('loc'))
  if (x=='1A'){
    stim[value==1, c('is_target','color','shape'):=.(1,'red',ifelse(`Target ID`==1, 'left triangle','right triangle'))]
  } else if (x=='1B'){
    stim[value==1, c('is_target','color','shape'):=.(1,'blue',ifelse(`Target ID`==1, 'left half-disk','right half-disk'))]
  } else if (x %in% c('2')) {
    # Target Or == 1 => target absent
    # Target Or == 0 => target present
    stim <- stim[`Target Or`  == 0, .SD[1], by=trial_id]

    stim[, c('is_target','color','shape','value'):=.(1,'red','T',1)]
  }  else if (x %in% c('3A','3B','3C','3D')){
    stim[value==-1, c('is_target','color','shape'):=.(1,'red',ifelse(`Target Or`==1, 'left T','right T'))]
  } else if  (x==4){
    stim[value==targetColor, c('is_target','color','shape'):=.(1,ifelse(value==1,'red','yellow'),ifelse(`Target ID`==1, 'left triangle','right triangle'))]
  }
  stim<-stim[value!=0]

  if (x%in%c('1A','1B')){

    stim[value>=2, c('is_target','color','shape'):=.(0,distrColor,distrShape)]
  } else  if (x %in% c('3A','3B','3C','3D')){
#   0=No item present
# 	1= Candidate (Red L)
# 	2= Lure (3A-Thick-weight Orange crosses, 3B-Thin-weight Orange 		Crosses 3C-Red Crosses 3D-Orange Squares)
# 	-1= Target (Red T)
    stim[value==1, c('is_target','color','shape'):=.(0,'red','L')]
    stim[value==2&x=='3A', c('is_target','color','shape'):=.(0,'orange','thick cross')]
    stim[value==2&x=='3B', c('is_target','color','shape'):=.(0,'orange','thin cross')]
    stim[value==2&x=='3C', c('is_target','color','shape'):=.(0,'red','cross')]
    stim[value==2&x=='3D', c('is_target','color','shape'):=.(0,'orange','square')]
  } else if  (x=='4'){
    stim[value!=targetColor, c('is_target','color','shape'):=.(0,ifelse(value==1,'red','yellow'), 'triangle')]
  }

  data[,block_n:=1]
  stim[,loc_id:=as.numeric(str_extract(variable,'\\d+'))]
  stim <- merge(stim, grid_data, by= 'loc_id')
  data[Error==3, Error:=2]
  if ('numLures'%in%names(data)) {
    data[,set_size:=numLures+numDistractors+1]
  } else data[,set_size:=numDistractors+1]
  if (x %in% c(2,'3A','3B','3C','3D')) {
    data[,correctResponse:=`Target Or`]
  } else data[,correctResponse:=`Target ID`]
  fwrite(data[,.(trial_id, Subject, block_n, Trial, set_size, correctResponse, 
                 condition = paste0(numDistractors, ' distractors'), 
                 keyResponse, acc=1-Error, RT)], file = sprintf('data/buetti_et_al_2016/exp%s_parsed.csv', x))
  if (x!='2') {# for E2 stimuli info is incorrect
    fwrite(stim[,.(trial_id, is_target, color, shape, posx_deg, posy_deg)], file = sprintf('data/buetti_et_al_2016/exp%s_stim.csv', x))
  } else {
    fwrite(stim[,.(trial_id, is_target, color, shape)], file = sprintf('data/buetti_et_al_2016/exp%s_stim.csv', x))
  }
  print(x)
  print(data[,lengthu(Subject)])
  print(data[,sort(unique(set_size))])
  config <- yaml.load_file(sprintf('data/buetti_et_al_2016/Buetti_Exp%s_config.yml',x))
  config$Dataset$Trial$optional$set_size <- 'set_size'
  config$Meta$Sample$optional$sample_size <- lengthu(data$Subject)
  if (x %in% c('3A','3B','3C','3D'))
    config$Dataset$Trial$optional$condition <- 'condition'
  write_yaml(config, sprintf('data/buetti_et_al_2016/Buetti_Exp%s_config.yml',x))

  load_data_neo4j('data/buetti_et_al_2016',sprintf('Buetti_Exp%s_config.yml',x))
}
