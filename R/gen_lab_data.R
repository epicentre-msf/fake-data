#generate lab data to match the linelist 

pacman::p_load(
  rio, # import funcs
  simulist, # generate fake linelist
  epiparameter, # get epi parameters
  fitdistrplus, # fit best distribution
  sf, # work with spatial data
  fs, # work with path
  here, # create relative paths
  janitor, # data cleaning
  lubridate, # date handling
  tidyverse # data science
)
conflicted::conflict_prefer("select", "dplyr")
conflicted::conflict_prefer("filter", "dplyr")

# read data
sim_ll <- readRDS(here::here("data", "clean", "simulated_measles_ll.rds"))

lab <- sim_ll |> 
  
  filter(epi_classification == "confirmed") |> 
  
  select(id, 
         outcome,
         date_onset,
         ct_value,
         date_admission, 
         date_outcome, 
         sub_prefecture
  ) |> 
  
  #Add a lab_id
  mutate(lab_id  = paste0(toupper(str_extract(sub_prefecture, ".[a-z]{2}")), "-")) |> 
  
  mutate(.by = lab_id, 
         lab_id = paste0(lab_id, seq_along(lab_id) ) ) 

lab <- lab |> 
  mutate(
    delay_hosp = as.numeric(date_outcome - date_admission ),
    delay_test = round(sample(1:delay_hosp, replace = TRUE, nrow(lab))),
    date_test = date_admission + delay_test, 
    lab_result = case_when( 
      
      outcome == "recovered" ~ sample(c("negative", "positive", "inconclusive"), replace = TRUE, size = nrow(lab), prob = c(.1, .85, .05)), 
      
      outcome == "dead" ~ sample(c("negative", "positive", "inconclusive"), replace = TRUE, size = nrow(lab), prob = c(.1, .85, .05)),
      
      .default = sample(c("negative", "positive", "inconclusive"), replace = TRUE, size = nrow(lab), prob = c(.1, .85, .05))
    ), 
    ct_value = if_else(lab_result == "positive",  round(digits = 1, rnorm(nrow(lab), 27.3)), NA) ) 

inc <- lab |> filter(lab_result == "inconclusive")


inc <- inc |> 
  mutate(
    lab_id = paste0(lab_id, "_retest"),
    date_test = date_test + sample(1:4, size = nrow(inc), replace = TRUE), 
    lab_result = case_when( 
      
      outcome == "recovered" ~ sample(c("negative", "positive", "inconclusive"), replace = TRUE, size = nrow(inc), prob = c(.1, .89, .01)), 
      
      outcome == "dead" ~ sample(c("negative", "positive", "inconclusive"), replace = TRUE, size = nrow(inc), prob = c(.1, .89, .01)),
      
      .default = sample(c("negative", "positive", "inconclusive"), replace = TRUE, size = nrow(inc), prob = c(.1, .89, .01))
    ), 
    
    ct_value = if_else(lab_result == "positive",  rnorm(nrow(inc), 27.3), NA)
  )

#bind inconclusives back 
lab <- bind_rows(lab, inc) |> select(id, lab_id, date_test, ct_value, lab_result)

lab_sub <- lab |> filter(date_test < "2023-06-11")


# rename some variables 
lab_raw <- lab |> 
  rename(
    `MSF Number ID` = id, 
    `Laboratory id` = lab_id, 
    ` Date of the test` =  date_test,
    `CT value` = ct_value, 
    `Final Test Result` = lab_result
  )

export(lab, here::here("data", "clean", "simulated_measles_lab_data.rds"))
export(lab_raw, here::here("data", "final", "msf_laboratory_moissala_2023-09-24.xlsx"))


lab_raw_sub <- lab_sub |> 
  rename(
    `MSF Number ID` = id, 
    `Laboratory id` = lab_id, 
    ` Date of the test` =  date_test,
    `CT value` = ct_value, 
    `Final Test Result` = lab_result
  )

export(lab_raw_sub, here::here("data", "final", "msf_laboratory_moissala_2023-06-11.xlsx"))

