library(RNeo4j)

graph = startGraph("http://localhost:7474/db/data/",username = 'neo4j', password = 'neo4jpass')
data_files <- list.files(data_dir,pattern='exp.*', full.names = T)

# This directory is a subdirectory of neo4j db. It should be create before import. 
neo4j_import = '~/Neo4j/default.graphdb/import/'
dir.create(neo4j_import, showWarnings = FALSE)
