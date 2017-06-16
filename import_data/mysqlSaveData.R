# adapted from https://stackoverflow.com/a/33769289/1344028
mysqlSaveData <- function(db, # db connection from RODBC
                          data, # a data frame
                          tableName, # table name, possibly qualified (e.g. "my_db.customers")
                          ...) # arguments to DBI::dbConnect
{
  
  TEMPFILE  <-  tempfile(tmpdir='E:/temp/',fileext='.csv')
  write.csv(data,TEMPFILE)
  fwrite(data,TEMPFILE,col.names = F, row.names = F)  
  query  <-  sprintf("LOAD DATA LOCAL INFILE '%s' 
                     INTO TABLE %s 
                     FIELDS TERMINATED BY ','
                     LINES TERMINATED BY '\r\n'
                     ;" , TEMPFILE, tableName)
  
  # WRITE THE DATA TO A LOCAL FILE
  #on.exit(file.remove(TEMPFILE))
  
  # SUBMIT THE UPDATE QUERY AND DISCONNECT
  sqlQuery(db, query)
}
