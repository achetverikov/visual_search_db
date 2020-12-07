for (exp_n in 1:2){
data <- fread(sprintf('data/corbett_munneke_2020/exp%s.csv',exp_n))

data[,training:=ifelse(BlockNr==1, 1, 0)]
fwrite(data, file=sprintf('data/corbett_munneke_2020/exp%s_parsed.csv', exp_n))
}
