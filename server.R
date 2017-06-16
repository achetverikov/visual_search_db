
# This is the server logic for a Shiny web application.
# You can find out more about building applications with Shiny here:
#
# http://shiny.rstudio.com
#

library(shiny)
library(data.table)
library(ggplot2)
library(ggthemes)
library(scales)
library(mongolite)
source('mongo_connect.R')

shinyServer(function(input, output) {

  output$distPlot <- renderPlot({
    color_var <- NULL
    
    if (length(input$color_var)>1){
      color_var<-paste0('interaction(',paste(input$color_var,collapse=','),')')
      
    }
    else if (!is.null(input$color_var)) {
      color_var<-sprintf("factor(%s)",input$color_var)
    }
    ggplot(data, aes_string(x='distrMean', y='rt', color=color_var))+geom_smooth()
    
  })
  output$debug <- renderPrint({
    getwd()
    print(str(input$color_var))
  })

})
