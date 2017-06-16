
# This is the user-interface definition of a Shiny web application.
# You can find out more about building applications with Shiny here:
#
# http://shiny.rstudio.com
#

library(shiny)
iv_vars_list <- c('Choose one or more'='','Distribution type'='dtype','Distribution SD'='dsd','Accuracy'='correct','Set size'='set_size') 
shinyUI(fluidPage(

  # Application title
  titlePanel("Old Faithful Geyser Data"),

  # Sidebar with a slider input for number of bins
  sidebarLayout(
    sidebarPanel(
      sliderInput("bins",
                  "Number of bins:",
                  min = 5,
                  max = 50,
                  value = 30),
      selectInput('color_var', "Variable for color:",iv_vars_list,multiple = T)
    ),

    # Show a plot of the generated distribution
    mainPanel(
      verbatimTextOutput("debug"),
      plotOutput("distPlot")
    )
  )
))
