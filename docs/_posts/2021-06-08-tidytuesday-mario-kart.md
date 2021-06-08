---
layout: post
title:  "Tidytuesday: Mario Kart World Records. How to build a scatter plot in ggplot2"
date: 2021-06-08 09:59:00 +0600
categories: data visualization, tidytuesday
permalink: /tidytuesday-mario-kart/
---

# Tidy Tuesday
This tutorial is inspired by the great article [The Evolution of a ggplot (Ep. 1)](https://www.cedricscherer.com/2019/05/17/the-evolution-of-a-ggplot-ep.-1/) of Cédric Scherer.

Tidy Tuesday is a weekly data visualization challenge for the R community. I will base this tutorial on [Mario Kart World Records](https://github.com/rfordatascience/tidytuesday/blob/master/data/2021/2021-05-25/readme.md) challenge. I want to analyze if records in the game grow over time as in [100 metres running](https://en.wikipedia.org/wiki/100_metres). A general idea of the chart: scatter plot with the year of a race and the time in seconds.

# Data preparation
First, I will add needed libraries, download the data and extract a year from the date.
```r
library(dplyr)
library(lubridate)
library(ggplot2)
library(ggtext) # Markdown format for text in ggplot2
library(showtext) # Fonts

font_add_google('Merriweather', 'Merriweather')
font_add_google('Montserrat', 'Montserrat')
showtext_auto()

tuesdata <- tidytuesdayR::tt_load('2021-05-25')
records <- tuesdata$records
records$date_year <- year(records$date)
```
# Building a plot
Now let's build a basic scatter plot with color parameter 'type' meaning single or three lap record. I chose this chart because I wanted to see destribution of records each year.
```r
records %>%
  ggplot(aes(x = date_year, y = time, col = type)) +
  geom_point(size = 1.5, alpha = 0.5)
```

![Basic Plot](/assets/posts/tidytuesday-mario-kart/1-basic-plot.svg)

On this stage I also do simple cleaning like adjusting axis names and title or making Y axis start from zero.
```r
records %>%
  ggplot(aes(x = date_year, y = time, col = type)) +
  geom_point(size = 1.5, alpha = 0.5) +
  scale_y_continuous(limits = c(0, 400), expand = c(0.005, 0.005)) + # Expansion so Y axis starts from 0
  labs(
    title = 'Yearly Time records',  
    x = '',
    y = ''
  )
```

![Plot title and axis names](/assets/posts/tidytuesday-mario-kart/2-labs.svg)

We see from the chart that most of the records for both laps are below 150 seconds and don't change much over time. Although I want to be sure, so let's add bigger dots for each year median.
```r
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
  labs(
    title = 'Yearly Time records',  
    x = '',
    y = ''
  )
```

![Add median calculation](/assets/posts/tidytuesday-mario-kart/3-medians.svg)

Indeed, median records don't change much except for years 2008-2010 that can be because of low number of drivers. I will add annotation and arrow to show it explicitly.
```r
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
  labs(
    title = 'Yearly Time records',  
    x = '',
    y = ''
  ) +
  annotate(
    'text',
    x = 2008,
    y = 225,
    size = 4,
    label = 'Lowest\nnumber of players'
  ) +
  geom_curve(
    x = 2008, y = 195, xend = 2009.5, yend = 120,
    arrow = arrow(length = unit(0.07, 'inch')),
    size = 0.4,
    curvature = 0
  )
```

![Annotation](/assets/posts/tidytuesday-mario-kart/4-annotation.svg)

The analytics part is ready!

# Legend & Colors
I chose different colors for a legend and plot lines, I use [Color Palettes](https://colorpalettes.net/color-palette-4255/) service for this.
```r
legend_colors <- c(`Single Lap` = '#bf3f27', `Three Lap` = '#72a2ac')
line_color <- 'gray50'
text_color <- 'gray30'
title_color <- 'gray20'
```
I decided to remove legend and include it in the title with proper color instead. To color the text I used `ggtext` library and `element_markdown()` in `theme()` settings. I also adjusted annotation and line colors.
```r
records %>%
  ggplot(aes(x = date_year, y = time, col = type)) +
  geom_point(size = 1.5, alpha = 0.5) +
  geom_point(
    data = median_time,
    aes(x = date_year, y = time),
    size = 7,
    alpha = 0.3
  ) +
  annotate(
    'text',
    x = 2008,
    y = 225,
    size = 4,
    label = 'Lowest\nnumber of players',
    color = title_color
  ) +
  geom_curve(
    x = 2008, y = 195, xend = 2009.5, yend = 120,
    arrow = arrow(length = unit(0.07, 'inch')),
    size = 0.4,
    curvature = 0,
    color = line_color
  ) +
  scale_y_continuous(limits = c(0, 400), expand = c(0.005, 0.005)) +
  labs(
    title = glue::glue("Yearly Time records:
                       <span style='color:{legend_colors['Single Lap']};'>Single Lap</span>
                       and <span style='color:{legend_colors['Three Lap']};'>Three Lap</span>"),  
    x = '',
    y = ''
  ) +
  scale_color_manual(values = legend_colors) +
  guides(col = FALSE)
```

![Legend](/assets/posts/tidytuesday-mario-kart/5-legend.svg)

As you can see, the title doesn't look like what we expect because we didn't adjust `theme()` yet. We will go back to it later.

# Fonts
I will use two fonts: Merriweather for title and annotation and Montserrat for general text. I decided to use serif and sans-serif families for contrast. Both are Google fonts, install them locally and add those lines to your code.
```r
font_add_google('Merriweather', 'Merriweather')
font_add_google('Montserrat', 'Montserrat')
showtext_auto()
```
# Theme
`ggplot2` has `theme()` component which allows to format your plot, i.e. clean it from extra grids, lines and ticks, change fonts and colors. Let's add final touch to our plot and that's it!
```r
records %>%
  ggplot(aes(x = date_year, y = time, col = type)) +
  geom_point(size = 1.5, alpha = 0.5) +
  geom_point(
    data = median_time,
    aes(x = date_year, y = time),
    size = 7,
    alpha = 0.3
  ) +
  annotate(
    'text',
    x = 2008,
    y = 225,
    size = 4,
    label = 'Lowest\nnumber of players',
    color = title_color
  ) +
  geom_curve(
    x = 2008, y = 195, xend = 2009.5, yend = 120,
    arrow = arrow(length = unit(0.07, 'inch')),
    size = 0.4,
    curvature = 0,
    color = line_color
  ) +
  scale_y_continuous(limits = c(0, 400), expand = c(0.005, 0.005)) +
  labs(
    title = glue::glue("Yearly Time records:
                       <span style='color:{legend_colors['Single Lap']};'>Single Lap</span>
                       and <span style='color:{legend_colors['Three Lap']};'>Three Lap</span>"),  
    x = '',
    y = ''
  ) +
  scale_color_manual(values = legend_colors) +
  guides(col = FALSE) +
  theme(
    panel.background = element_blank(),
    axis.ticks = element_blank(),
    panel.grid = element_blank(),
    axis.line.x.bottom = element_line(color = line_color),
    axis.line.y.left = element_line(color = line_color),
    plot.title = element_markdown(color = title_color, size = 14, family = 'Merriweather'),
    text = element_text(color = text_color, size = 11, family = 'Montserrat')
  )
```
![Final Plot](/assets/posts/tidytuesday-mario-kart/6-final-plot.svg)

Thanks for reading! Find the full code [here](https://github.com/bjolko/bjolko.github.io/blob/master/docs/assets/posts/tidytuesday-mario-kart/chart_script.r) :)
