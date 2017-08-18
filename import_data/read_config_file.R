library(data.table)
library(yaml)

read_vs_config <- function (filename){
  
  message(sprintf('Processing configuration file %s', filename ))
  conf <- yaml.load_file(filename)
  
  # Check required fields
  
  # Load config template
  conf_template <- yaml.load_file('data/import_conf_template.yaml')
  error_counter = 0
  
  # Go through each section, checking for required fields and looking for any unknown fields
  for (section in names(conf_template)){
    # Stimulus section is optional, so it's OK if it doesn't exist
    if (section!='Stimulus' | exists('Stimulus',conf)){
      if (!exists(section, conf)) {
        warning(sprintf('Section "%s" is absent from the import configuration file %s', section, filename))
        error_counter = 1
      }
      else {
        if (section=='Experiment'&&!exists('added_ts',conf[[section]]$required)){
          conf[[section]]$required$added_ts <- as.numeric(Sys.time())
        }
        missing_fields <- setdiff(names(conf_template[[section]]$required), names(conf[[section]]$required))
        if (length(missing_fields)>0){
          warning(sprintf('The following _required_ fields are absent from the section %s: %s', section, paste(missing_fields, collapse = ', ')))
          error_counter = 1
        }
        
        unknown_required_fields <- setdiff(names(conf[[section]]$required), names(conf_template[[section]]$required))
        if (length(unknown_required_fields)>0){
          warning(sprintf('The following _required_ fields are unknown in the section %s: %s', section, paste(unknown_required_fields, collapse = ', ')))
          error_counter = 1
        }
        unknown_optional_fields <- setdiff(names(conf[[section]]$optional), names(conf_template[[section]]$optional))
        
        # Optional fields described in Experiment section of config template can be also present in Block and Trial sections
        if (section %in% c('Block', 'Trial')){
          unknown_optional_fields <- setdiff(unknown_optional_fields,names(conf_template$Experiment$optional)) 
        }
          
        if (length(unknown_optional_fields)>0){
          warning(sprintf('The following optional fields are unknown in the section %s: %s', section, paste(unknown_optional_fields, collapse = ', ')))
          error_counter = 1
        }
      }
    }
  }
  if (error_counter>0) stop('There were errors in configuration file, please fix them before proceeding.')
  else message('Configuration file is correct.')
  
  # Create "all" sublists for subjects, blocks, trials, and stimuli for the ease of later processing
  
  for (section in setdiff(names(conf), c('Maintainer'))){
    conf[[section]]$all<-append(conf[[section]]$required, conf[[section]]$optional)
  }
  
  conf
}
