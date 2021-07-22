# Libraries & Set up ----

library(readr)
library(dplyr)
library(tidyr)

library(stringr)
library(lubridate)

library(tidytext)
library(stopwords)
library(SnowballC)
library(textcat)

library(ggplot2)

# Data Load ----

path <- './data/'
text_files <- dir(path, pattern = '*.txt')

speeches <- lapply(paste(path, text_files, sep = ''), read_file)
names(speeches) <- str_remove(text_files, '\\.txt')

# General data cleaning & Extracting Sentences
df_speeches <- 
  speeches %>% 
  as.data.frame(stringsAsFactors = FALSE) %>% 
  pivot_longer(
    everything(), 
    names_to = 'dt', 
    values_to = 'speech'
  ) %>% 
  mutate(
    dt = ymd(str_remove(dt, 'X'))
  ) %>% 
  unnest_tokens(speech, speech, token = 'sentences', to_lower = F)

# Tokenization by words, Stemming
df_tokens <- 
  df_speeches %>% 
  unnest_tokens(word, speech, drop = F) %>% 
  mutate(
    word_stemmed = wordStem(word, language = 'ru'),
  )

# Text Filtering ----
## Stop Words ----

# Dictionaries
stopwords_ru <- c(stopwords('ru'), stopwords('ru', source = 'stopwords-iso')) %>% unique()
stopwords_kz <- c(stopwords('kk', source = 'nltk'), stopwords_kz_extension) %>% unique()
stopwords_kz_extension <- read_file('https://pastebin.com/raw/hvN8hVd8') %>% str_split('\r\n') %>% unlist()
general_stopwords <- c('тенге', 'кстати')

# Stopwords = words that occur in every (or almost every) document
calculated_stopwords <- 
  df_tokens %>% 
  group_by(word) %>% 
  summarise(dates = n_distinct(dt)) %>% 
  ungroup %>% 
  filter(dates >= (length(text_files) - 1)) %>% 
  pull(word) %>% 
  unique()

## Filtered df -----

# Removing stopwords
df_filtered <- 
  df_tokens %>% 
  filter(
    !word %in% c(stopwords_ru, stopwords_kz, general_stopwords, calculated_stopwords),
    !str_detect(word, '[0-9]|[[:punct:]]'),
  )

# New thoughts ----

# Words that occurred in only 1 speech, taking Top-5 here
df_new_words <- 
  df_filtered %>% 
  count(dt, word_stemmed, name = 'freq') %>% 
  group_by(word_stemmed) %>% 
  mutate(dates = n_distinct(dt)) %>% 
  filter(dates == 1, freq > 1) %>% 
  arrange(dt, -freq) %>% 
  group_by(dt) %>% 
  slice(1:5)

# Extracting "New thoughts" for each year, i.e. sentences containing new words
df_new_thoughts <- 
  df_filtered %>% 
  inner_join(select(df_new_words, dt, word_stemmed)) %>% 
  group_by(dt, word_stemmed) %>%
  mutate(rank = row_number()) %>% 
  ungroup %>% 
  filter(rank == 1) %>% 
  distinct(dt, speech)