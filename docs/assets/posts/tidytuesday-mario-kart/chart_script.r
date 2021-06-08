library(dplyr)
library(lubridate)
library(ggplot2)
library(ggtext) 
library(showtext)

font_add_google('Merriweather', 'Merriweather')
font_add_google('Montserrat', 'Montserrat')
showtext_auto()

tuesdata <- tidytuesdayR::tt_load('2021-05-25')
records <- tuesdata$records
drivers <- tuesdata$drivers

records$date_year <- year(records$date)

median_time <- 
  records %>% 
  group_by(type, date_year) %>% 
  summarise(time = median(time), n = n()) %>% 
  arrange(type, date_year)

# https://colorpalettes.net/color-palette-4255/
legend_colors <- c(`Single Lap` = '#bf3f27', `Three Lap` = '#72a2ac')
line_color <- 'gray50'
text_color <- 'gray30'
title_color <- 'gray20'

records %>% 
  ggplot(aes(x = date_year, y = time, col = type)) +
  geom_point(size = 1.5, alpha = 0.5) +
  geom_point(
    data = median_time, 
    aes(x = date_year, y = time), 
    size = 7, 
    alpha = 0.3
  ) +
  scale_y_continuous(limits = c(0, 400), expand = c(0.005, 0.005)) +
  annotate(
    'text', 
    x = 2008, 
    y = 225, 
    family = 'Merriweather',
    size = 2.8, 
    color = title_color,
    label = 'Lowest\nnumber of players'
  ) +
  geom_curve(
    x = 2008, y = 195, xend = 2009.5, yend = 120,
    arrow = arrow(length = unit(0.07, 'inch')), size = 0.4,
    color = line_color,
    curvature = 0
  ) +
  guides(col = FALSE) +
  scale_color_manual(values = legend_colors) +
  labs(
    title = glue::glue("
                       Yearly Time records: 
                       <span style='color:{legend_colors['Single Lap']};'>Single Lap</span> 
                       and <span style='color:{legend_colors['Three Lap']};'>Three Lap</span>"
            ), 
    x = '', 
    y = ''
  ) +
  theme(
    panel.background = element_blank(),
    axis.ticks = element_blank(),
    panel.grid = element_blank(),
    axis.line.x.bottom = element_line(color = line_color), 
    axis.line.y.left = element_line(color = line_color), 
    plot.title = element_markdown(color = title_color, size = 11, family = 'Merriweather'),
    text = element_text(color = text_color, family = 'Montserrat')
  )

ggsave('tidytuesday-2021-05-25.svg',  width = 10, height = 5, dpi = 300)
ggsave('tidytuesday-2021-05-25.png',  width = 6, height = 3, dpi = 300)
