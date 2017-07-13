# visual_search_db
Visual Search Database

This projects aims to create a database for visual search datasets capable of handling theoretically any kind of visual search data. 
The second goal is to create a standard language for description of such data sets.

For those who wants to run a database on their own machine - installation guide v0.01
1) Get your own copy of the project - fork it or just clone it if you have write access
2) Download & install neo4j from https://neo4j.com/
3) Start neo4j - preferably use a default location for the database
4) Browse to http://127.0.0.1:7474/browser/ (or any other link neo4j shows you after starting), enter the default credentials (neo4j/neo4j) and set up your new password 
5) Edit import_data/connect_to_neo4j.R - set username and password for neo4j, edit neo4j import path if you used non-default location for the database
6) Open the project (visual_search_db.Rproj) with RStudio or just set the directory to the main directory of the project
7) Run `source('import_data/parse_config_for_neo4j.R')` 

Voila! In theory, everything should work now. You can test it by running:
> load_data_neo4j('data/chetverikov_kristjansson_2015','import_conf.yaml')
> load_data_neo4j('data/chetverikov_kristjansson_campana_2016','exp1_config.yaml')

Both should run without errors, the first one is fast, the second one is slower.

