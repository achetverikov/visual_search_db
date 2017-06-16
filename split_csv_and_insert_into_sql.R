library('RODBCext')
library(data.table)

# dbhandle <- odbcDriverConnect('driver={SQL Server};server=localhost;database=vissearch;;trusted_connection=true')
# res <- sqlQuery(dbhandle, 'select * from information_schema.tables')
odbcCloseAll()
db <- odbcConnect('vissearch')

sqlQuery(db, 'delete from trials')
sqlQuery(db, 'delete from blocks')
sqlQuery(db, 'delete from global_parts_num')
sqlQuery(db, 'delete from global_parts_char')

sqlQuery(db, 'delete from subjects')
sqlQuery(db, 'delete from exps')
sqlQuery(db, 'delete from equipment')
sqlQuery(db, 'delete from authors')


data<-fread('data/exp1.csv')

author<-data.frame(name = 'Andrey Chetverikov', email = 'andrey@hi.is')

# Check if author exists

author_id <- sqlExecute(db, "select author_id from authors where email = ?", author$email, fetch=T)[,1]
if (length(author_id)==0){
  sqlExecute(db, 'insert into authors (name, email) values (?, ?)', author)
  author_id <- sqlExecute(db, 'select LAST_INSERT_ID()', fetch=T)[,1]
}

equipment <-data.table(display_res_x=1366, display_res_y=768, display_size_x=310, display_size_y=170, display_distance=570, display_name='DELL Vostro 5470 laptop', os_name='Windows 8', software='PsychoPy', response_device='laptop keyboard')

sqlExecute(db, paste0('insert into equipment (',paste(colnames(equipment), collapse = ','),') values (', paste(rep('?',ncol(equipment)), collapse = ','),')'), equipment)

equip_id <- sqlExecute(db, 'select LAST_INSERT_ID()', fetch=T)[,1]

exp_info <- data.table(exp_name = data$expName[1], task_id = sqlQuery(db, 'select task_id from tasks where name="outlier"')[1,], data_url = "https://osf.io/h4epz/", display_arr = 'jittered_grid', exp_date='2015-09-04', author_id=author_id, equip_id = equip_id, citation_info = 'Chetverikov, A., Campana, G., Kristjansson, Á. (2016). Building ensemble representations: How the shape of preceding distractor distributions affects visual search. Cognition, 153, 196–210. http://doi.org/10.1016/j.cognition.2016.04.018')

sqlExecute(db, paste0('insert into exps (',paste(colnames(exp_info), collapse = ','),') values (', paste(rep('?',ncol(exp_info)), collapse = ','),')'), exp_info)

exp_id <- sqlExecute(db, 'select LAST_INSERT_ID()', fetch=T)[,1]

subjects <- unique(data[,c('subjectId','subjectAge', 'subjectGender'), with=F], by=c('subjectId','subjectAge', 'subjectGender'))
subjects[,exp_id:=exp_id]

# sqlPrepare(db,"insert into subjects (age, gender, exp_id) values (?,?,?)")
# sqlExecute(db, NULL, subjects[,.(subjectAge,subjectGender, exp_id)])
# subj_iid<-sqlExecute(db, 'select LAST_INSERT_ID()', fetch=T)[,1]

subjects[,sql_string:=sprintf('("%s","%s",%i)',subjectAge, subjectGender, exp_id)]
queries <- paste0(
  'INSERT INTO subjects (age, gender, exp_id) VALUES ',paste(subjects$sql_string,collapse = ', ')
)

sqlQuery(db,queries)

subj_iid<-sqlExecute(db, 'select LAST_INSERT_ID()', fetch=T)[,1]
subjects[,subj_id:=subj_iid:(subj_iid+.N-1)]

data[,blockId:=.GRP, by=.(subjectId,block, session, dtype, dsd)]

blocks <- unique(data[,.(subjectId,blockId,block, session, dtype, dsd, distrMean)])
blocks <- merge(blocks, subjects, by='subjectId')

# sqlPrepare(db, "insert into blocks (inner_id, session, subj_id) values (?,?,?)")
# sqlExecute(db, NULL, blocks[,.(blockId, session, subj_id)])
# blocks<-sqlExecute(db,'select b.* from blocks b join subjects s on s.subj_id = b.subj_id where exp_id = ?', exp_id, fetch=T)

saveData(db,blocks[,.(block_id=NA, session, subj_id)],'blocks')

block_iid<-sqlExecute(db, 'select LAST_INSERT_ID()', fetch=T)[,1]
blocks[,block_id:=block_iid:(block_iid+.N-1)]

sqlQuery(db, "insert ignore into pars_types (name, type) values ('rg_distr_pdf', 2), ('rg_distr_sd', 1), ('rg_distr_min', 1), ('rg_distr_max', 1), ('rg_distr_mean', 1)")

rg_pars<-sqlExecute(db, 'select * from pars_types where name like "rg%"', fetch=T)
blocks_pars<-melt(blocks, measure.vars = patterns('^d.*'))
blocks_pars[,variable:=plyr::mapvalues(variable,c('dtype','dsd','distrMean'),c('rg_distr_pdf','rg_distr_sd','rg_distr_mean'))]

blocks_pars<-merge(blocks_pars, rg_pars, by.x='variable', by.y='name')

saveData(db, blocks_pars[type==1,.(par_type_id, node_id = block_id, level = 2, value)], 'global_pars_num')
saveData(db, blocks_pars[type==2,.(par_type_id, node_id = block_id, level = 2, value)], 'global_pars_char')

sqlPrepare(db, 'insert into trials (block_id, rt, correct) select block_id, ?, ? from blocks b where inner_id = ?')
sqlExecute(db, NULL, data[,list(rt, correct, blockId)])
