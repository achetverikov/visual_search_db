#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#

library(shiny)
library(ggplot2)
library(data.table)
library(apastats)
library(plyr)
library(dplyr)
library(stringr)
library(colorblindr)
library(patchwork)

cache_setting = 1 # 0 - do not use cache, 1 - create cache from Neo4j, 2 - use cache
cache_folder = 'cache'
if (!dir.exists(cache_folder)) dir.create(cache_folder)

if (cache_setting<2){
    library(RNeo4j)

    source('import_data/connect_to_neo4j.R')
    source('import_data/parse_config_for_neo4j.R')
}

default_font = 'Gill Sans Nova Light'

default_font_size <- 14
default_font_size_mm <- default_font_size / ggplot2:::.pt
default_line_size <- 1 / .pt

default_theme <-
    theme_light(base_size = default_font_size, base_family = default_font) +
    theme(
        axis.line = element_line(size = I(0.5)),
        axis.ticks = element_line(size = I(0.25), colour = 'gray'),
        axis.line.x = element_line(),
        axis.line.y = element_line(),
        panel.grid = element_line(colour = 'gray', size = I(0.5)),
        panel.grid.minor = element_blank(),
        legend.title = element_text(size = rel(1)),
        strip.text = element_text(size = rel(1), color = 'black'),
        axis.text = element_text(size = rel(0.7)),
        axis.title = element_text(size = rel(1)),
        panel.border = element_blank(),
        strip.background = element_blank(),
        legend.position	= 'right',
        plot.title = element_text(size = rel(1), hjust = 0.5),
        text = element_text(size = default_font_size),
        legend.text = element_text(size = rel(1)),
        axis.line.x.bottom = element_blank(),
        axis.line.y.left = element_blank()
    )

theme_set(default_theme)

# Define UI for application that draws a histogram
ui <- fluidPage(# Application title
    titlePanel("Visual Search Database"),
    
    # Sidebar with a slider input for number of bins
    sidebarLayout(
        sidebarPanel(
            tags$h4('What do you want to see?'),

            selectInput("effect_type", "Effect:", list('Set size' = 'set_size')), 
            checkboxInput('plot_accuracy', 'Plot accuracy', value = F),
            checkboxInput('plot_error_RTs', 'Plot RTs for errors', value = F),
            checkboxInput('by_exp', 'Plot results separately for each experiment & condition', value = T),
            checkboxInput('log_scale', 'Log-transform RTs', value = F),
            checkboxInput('trim_outliers', 'Remove outliers (±3 SD by subject)', value = T),
            checkboxInput('center_by_subj', 'De-mean each subject RTs', value = T),
       
        tags$h4('Database statistics:'),
        htmlOutput('dbStatsOutput')
        ),
        # Show a plot based on the selection
        mainPanel(
            tags$h2('Results:'),
            plotOutput("resultsPlot"),
            tags$h2('Sources:'),
            htmlOutput('resultsSources')
        )
    ))

# Define server logic required to draw a histogram
server <- function(input, output) {
    dbStats <- reactive({
        if (cache_setting!=2){
            sources_info <- query_neo4j('match (e:Experiment) return distinct e.paper_citation_info')
            all_info <- cypherToList(graph, 'CALL apoc.meta.stats() YIELD labels RETURN labels' ) 
            all_info <- all_info[[1]]$labels
            res <- list(sources = sources_info, all = all_info)
    
            if (cache_setting==1) saveRDS(res, file.path(cache_folder,'dbStats.rds'))
            res
        } else 
            readRDS(file.path(cache_folder,'dbStats.rds'))
        })
    dataInput <- reactive({
        if (input$effect_type == 'set_size') {
            if (cache_setting!=2){
                print('Querying Neo4j DB')
                query = 'MATCH (e:Experiment)--(s:Subject)--(b:Block)--(t:Trial)
                                  WHERE  exists(b.set_size) OR exists(t.set_size) AND ((not exists(t.target_present)) or t.target_present) AND (b.training OR not exists(b.training))
                                  RETURN ID(e) as exp_id, e.task, b.task, t.task, b.condition, t.condition, ID(s) as subj_id, e.set_size, b.set_size, t.set_size, t.rt as rt, t.accuracy as accuracy'
                data = query_neo4j(query)
                setDT(data)
                exp_info <- query_neo4j(sprintf('match (e:Experiment) where ID(e) in [%s] return e.full_name, e.paper_citation_info, ID(e)', paste(data[,unique(exp_id)],collapse=',')))
                setDT(exp_info)
                data[, ss := rowSums(.SD[, .(e.set_size, b.set_size, t.set_size)], na.rm = T)]
                data[, task:=ifelse(!is.na(e.task), e.task, ifelse(!is.na(b.task), b.task, t.task))]
                data[!is.na(b.condition)|!is.na(t.condition),condition:=paste0(ifelse(is.na(b.condition),'',b.condition), ifelse(is.na(t.condition),'',t.condition))]
                if (data[,any(rowSums(!is.na(.SD))>1),.SDcols=patterns('\\.task')])
                    warning('Some rows in the results have task set at multiple levels')
                if (data[,any(rowSums(!is.na(.SD))>1),.SDcols=patterns('\\.condition')])
                    warning('Some rows in the results have condition set at multiple levels')
                if (data[,any(rowSums(!is.na(.SD))>1),.SDcols=patterns('\\.set_size')])
                    warning('Some rows in the results have set size set at multiple levels')
                data[, n_set_sizes_by_subj := lengthu(ss), by = subj_id]
                data <- data[n_set_sizes_by_subj > 1, ]
                data[is.na(condition), condition:='']
                data[, task_name := str_to_title(str_replace(task, '_', ' '))]
                data[, task_label := dplyr::case_when(task_name=='Feature Search'~'Feature',grepl('[A-Z] Among [A-Z]',task_name)~'Letters',T~task_name)]
                data[,correctf:=ifelse(accuracy, 'Correct responses', 'Errors')]

                res <- list(data = data, exp_info = exp_info)
                if (cache_setting==1) saveRDS(res, file.path(cache_folder,'set_size_effects.rds'), compress = T)
                res
            } else 
                readRDS(file.path(cache_folder,'set_size_effects.rds'))
        }
    })
    output$resultsPlot <- renderPlot({
        if (input$effect_type == 'set_size') {
            by_list <- c('task_label','ss','correctf')

            if (input$by_exp){
                by_list <- c(by_list,'exp_id','condition')
            }
            
            data <- copy(dataInput()$data)
            
            if (input$log_scale){
                data[, rt := log(rt)]
                data <- data[!is.infinite(rt)] # in case there are zeros in RTs
                rt_y_lab <- 'Change in Response Time (log-ms)'
            } else rt_y_lab <- 'Change in Response Time (ms)'
            
            if (input$center_by_subj){
                data[, rt := rt - mymean(rt), by = .(subj_id, correctf)]
            }

            if (input$trim_outliers){
                data[, rt := ifelse(abs(rt-mymean(rt))>3*sd(rt, na.rm = T), NA, rt), by = .(subj_id, correctf)]
                data <- data[!is.na(rt)]
            }
            

            aes_list <- .(
                    x = ss,
                    y = rt,
                    color = task_label
                )
            if (input$by_exp) {
                data[,exp_cond:=factor(ifelse(condition!='', interaction(exp_id, condition), as.character(exp_id)))]
                data[,exp_task:=factor(interaction(task_label, exp_cond))]
                aes_list <- append(aes_list, .(group = exp_task))
                withinvars_rt <- c('exp_cond','exp_id','condition')

            } else  withinvars_rt <- c('exp_id')

            if (input$plot_error_RTs){
                withinvars_rt = c('correctf',withinvars_rt)
            }
            
            if (!input$plot_error_RTs) data_rt <- data[accuracy==1]
            else data_rt <- data
            p_rt <- plot.pointrange(data_rt,
                            aes_list,
                            wid = 'subj_id',
                            withinvars = withinvars_rt,
                            connecting_line = T,
                            do_aggregate = F, print_aggregated_data = T
            ) + 
                labs(x = 'Set Size',
                     y = rt_y_lab,
                     color = 'Task') + 
                theme(
                    legend.position = c(1, 0),
                    legend.justification = c(1, 0)
                ) + 
                scale_color_OkabeIto()
            if (input$plot_error_RTs) p_rt <- p_rt + facet_wrap( ~ correctf) 
            plot_caption <- sprintf('This plot is based on %s studies, %s subjects, %s trials', data[,lengthu(exp_id)], data[,.N,by=.(exp_id, subj_id)][,.N], data[,.N])
            if (input$plot_accuracy) {
                data[,acc_percent:=as.numeric(accuracy)*100]
                aes_list$y <- quote(acc_percent)

                p_acc <- plot.pointrange(data,
                            aes_list,
                            wid = 'subj_id',
                            connecting_line = T,
                            do_aggregate = F, print_aggregated_data = T
            ) + 
                labs(x = 'Set Size',
                     y = 'Accuracy (% correct)',
                     color = 'Task') + 
                theme(
                    legend.position = c(1, 0),
                    legend.justification = c(1, 0)
                ) +
                scale_color_OkabeIto() 
                if (input$plot_error_RTs) {
                    p_acc <- p_acc + facet_wrap(~'Accuracy')
                    plot_widths <- c(2/3, 1/3)
                } else plot_widths <- c(.5, .5)
                p_rt + p_acc + plot_annotation(caption = plot_caption) + plot_layout(guides='collect', widths = plot_widths) &  theme(legend.position='bottom') & guides(color = guide_legend(nrow = 2)) 
            } else plotly::ggplotly(p_rt + plot_annotation(caption = plot_caption))

        }
    }, res = 72, type = 'cairo')
    output$resultsSources <- renderUI({
        tags$ul(lapply(dataInput()$exp_info[, unique(e.paper_citation_info)], tags$li))
        
    })
    output$dbStatsOutput <- renderUI({
        sources_info <- dbStats()$sources
        all_info <- dbStats()$all
        tags$ul(lapply(c(paste0('Papers/sources: ', nrow(sources_info)),
                 paste0('Experiments: ', all_info$Experiment),
                 paste0('Participants: ', all_info$Subject),
                 paste0('Trials: ', all_info$Trial))
                 , tags$li))

    })
    
    
}

# Run the application
shinyApp(ui = ui, server = server)
