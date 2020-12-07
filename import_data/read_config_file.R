library(data.table)
library(yaml)

read_vs_config <- function (filename){
  
  message(sprintf('Processing configuration file %s', filename ))
  full_conf <- yaml.load_file(filename)
  
  # Check required fields
  
  # Load config template
  conf_template <- yaml.load_file('data/import_conf_template.yaml')
  error_counter = 0
  if (length(setdiff(names(conf_template), names(full_conf)))>0) {
    error_counter = 1
    warning(sprintf('One of the top-level sections (%s) is missing from the config.', paste(setdiff(names(conf_template), names(full_conf)), collapse = ', ')))
  }
  # Go through each section, checking for required fields and looking for any unknown fields
  for (l1_section in names(conf_template)){
    conf <- full_conf[[l1_section]]
    for (section in names(conf)){
      # Stimulus section is optional, so it's OK if it doesn't exist
      if (section!='Stimulus' | exists('Stimulus',conf)){
        if (!exists(section, conf)) {
          warning(sprintf('Section "%s" is absent from the import configuration file %s', section, filename))
          error_counter = 1
        }
        else {
          if (section=='Description'&&!exists('timestamp',conf[[section]]$required)){
            conf[[section]]$required$timestamp <- as.numeric(Sys.time())
          }
          if (section=='Description'&&!exists('full_name',conf[[section]]$required)){
            conf[[section]]$required$full_name <- paste(substr(str_to_lower(str_replace_all(conf$Authors$required$authors_names,'\\W','_')), 1,15), conf[[section]]$required$timestamp)
          }
          missing_fields <- setdiff(names(conf_template[[l1_section]][[section]]$required), names(conf[[section]]$required))
          if (length(missing_fields)>0){
            warning(sprintf('The following _required_ fields are absent from the section %s: %s', section, paste(missing_fields, collapse = ', ')))
            error_counter = 1
          }
          
          unknown_required_fields <- setdiff(names(conf[[section]]$required), names(conf_template[[l1_section]][[section]]$required))
          if (length(unknown_required_fields)>0){
            warning(sprintf('The following _required_ fields are unknown in the section %s: %s', section, paste(unknown_required_fields, collapse = ', ')))
            error_counter = 1
          }
          unknown_optional_fields <- setdiff(names(conf[[section]]$optional), names(conf_template[[l1_section]][[section]]$optional))
          
          # Optional fields described in Experiment section of config template can be also present in Block and Trial sections
          if (section %in% c('Block', 'Trial')){
            unknown_optional_fields <- setdiff(unknown_optional_fields,names(conf_template$Dataset$Experiment$optional)) 
          }
            
          if (length(unknown_optional_fields)>0){
            warning(sprintf('The following optional fields are unknown in the section %s: %s', section, paste(unknown_optional_fields, collapse = ', ')))
            error_counter = 1
          }
        }
      }
      full_conf[[l1_section]][[section]]<-conf[[section]]
    }
  }
  if (error_counter>0) stop('There were errors in configuration file, please fix them before proceeding.')
  else message('Configuration file is correct.')
  
  # Create "all" sublists for subjects, blocks, trials, and stimuli for the ease of later processing
  
  for (section in names(full_conf$Dataset)){
    full_conf$Dataset[[section]]$all<-append(full_conf$Dataset[[section]]$required, full_conf$Dataset[[section]]$optional)
  }
  
  full_conf
}

reformat_configs <- function(config_file){
  backup_name <- paste0(config_file,'_backup')
  if (file.exists(backup_name)){
      conf_template <- yaml.load_file(backup_name)
  }  else {
    conf_template <- yaml.load_file(config_file)
    file.copy(config_file, backup_name, overwrite = F)
  }
  names(conf_template$Maintainer$required) <- paste0('maintainer_', names(conf_template$Maintainer$required))
  conf_new <- list()
  meta <- list(Maintainer = conf_template$Maintainer, Description = list())
  dataset <- conf_template[setdiff(names(conf_template),'Maintainer')]
  meta$Description$required <- list(trials_file = dataset$Experiment$required$trials_file, full_name = dataset$Experiment$required$full_name)
  meta$Description$optional <- append(dataset$Experiment$required[names(dataset$Experiment$required)%in%c('published','citation_info')],
                                      dataset$Experiment$optional[c('stimuli_file','data_url')])
  meta$Description$optional <- reshape::rename(meta$Description$optional, c(published  = 'paper_published', citation_info = 'paper_citation_info' ))
  dataset$Experiment$required$task <- conf_template$Experiment$optional$task
  dataset$Experiment$optional[c('stimuli_file','data_url','task')] <- NULL
  dataset$Experiment$optional$display_device_name <- dataset$Experiment$required$display_name
  dataset$Experiment$optional <- append(dataset$Experiment$optional, dataset$Experiment$required[c('response_device')])
  dataset$Experiment$required[c('trials_file','full_name','citation_info','published','display_name','response_device')] <- NULL
  meta$Description$optional <- meta$Description$optional[!is.na(names(meta$Description$optional))]
  write_yaml(list(Meta = meta, Dataset = dataset), config_file)
  read_vs_config(config_file)
}
