# Visual Search Database

This projects aims to create a database for visual search datasets capable of handling theoretically any kind of visual search data. 
The second goal is to create a standard language for description of such data sets.

## Background

Visual search has a relatively long history and there are gazzilions of experiments done every year. Yet, when Andrey Chetverikov started doing his experiments he was really frustrated because it was quite difficult to find clear answers for seemingly simple questions (e.g., how does the density of distractors interacts with a number of distractors?). On the other hand, other simple questions seem to resurface over and over again as if the data collected before did not exist. We believe that part of the problem is that it is really difficult to find some data collected before you. Even now, when there is a strong movement towards open science, not many people publish their data and it is often pre-processed so that only the authors hypothesis can be tested.
 
We have been working on a database and a standard for visual search experiments data. The idea is that the data should allow to recreate the stimuli display precisely (and include the variables such as ITI that might affect the results). The final version of the project should allow the researchers to upload their data in a typical format (csv) along with a configuration file so that it will be automatically processed and included in the database. Finally, an online interface (Shiny?) should be available to show some of the typical effects known in visual search. It’s a daunting task, but we had some progress, so that now the data from our own  experiments can be imported along with some of the publicly-available sets.

## Installation

For those who wants to run a database on their own machine - installation guide v0.01
1) Get your own copy of the project - fork it or just clone it if you have write access
2) Download & install neo4j from https://neo4j.com/
3) Start neo4j - preferably use a default location for the database
4) Browse to http://127.0.0.1:7474/browser/ (or any other link neo4j shows you after starting), enter the default credentials (neo4j/neo4j) and set up your new password 
5) Edit import_data/connect_to_neo4j.R - set username and password for neo4j, edit neo4j import path if you used non-default location for the database
6) Open the project (visual_search_db.Rproj) with RStudio or just set the directory to the main directory of the project
7) You may need to install additional packages: 
> install.packages('RNeo4j','yaml', 'data.table','stringr','digest')
8) Run `source('import_data/parse_config_for_neo4j.R')` 


Voila! In theory, everything should work now. You can test it by running:
> load_data_neo4j('data/chetverikov_kristjansson_2015','import_conf.yaml')
> load_data_neo4j('data/chetverikov_kristjansson_campana_2016','exp1_config.yaml')

Both should run without errors, the first one is fast, the second one is slower.

