library(RNeo4j)

debug = 0 

graph = startGraph("http://localhost:7474/db/data/",username = 'neo4j', password = 'password')

# This directory is a subdirectory of the neo4j db. It should be create before importing data if it does not exist. 
neo4j_import = '/Users/andche/Library/Application Support/com.Neo4j.Relate/Data/dbmss/dbms-13c3f0ca-ba6d-41ef-ae9e-8d56bc11a574/import/'
dir.create(neo4j_import, showWarnings = FALSE, recursive = T)
