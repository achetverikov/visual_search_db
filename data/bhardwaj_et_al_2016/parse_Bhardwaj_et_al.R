data <- fread('Bhardwaj_et_al_2016_data.csv', dec = ',')
data[,trial_id := 1:.N]
data[,session:=.GRP, by = .(subjnr, rho)]
data[,session:=session-min(session)+1, by = .(subjnr)]
data[,rt:=NA]
stim <- melt(data, measure.vars = patterns('ort'), id.vars = 'trial_id')
stim[,is_target:=as.numeric(value==0)]
stim[,variable:=NULL]
setnames(stim,'value','ori')

fwrite(data[,.SD,.SDcols = !patterns('ort')], 'exp.csv')
fwrite(stim, 'stimuli.csv')
