
# Premise

Despite the progress in HIV care in suppressing viral load, disengagement from HIV care remains a significant issue that impairs the 
path of achieving the global target to end the HIV/AIDS epidemic by 2030, set forth by WHO and the Joint United Nations Programme on HIV/AIDS (UNAIDS). In light of the above, we sought to develop and validate data-driven / AI rules than can be used to foster the early identification of patients at risk of disengagement from care.

# Objective 

> The main objective of this study is to predict disengagement by one month denoted by y_2. 

# Training & Validation of Models

We leveraged Super Learner (Stacked Ensamble) algorithm to train and validated ML models. The details of implementation can be found here:

https://rpubs.com/akimaina/hiv-disengagement-prediction

# Folder Structure

In this repository, we have the following folders:

* EHR Data Extraction SQL - SQL query used to extract data from EHR
* data - containing sample synthetic data: This is the exact output that the SQL query above provides
* model - containing the exported models, ranked ordered by AUC performance in descending order
* training scripts - containing all the scripts used to train and validate the model. Documentation on the methodology can be found here: https://rpubs.com/akimaina/hiv-disengagement-prediction

We also have the following files:

* prediction.Rmd - A file containing an outline of how to use the model to predict.
* helpers.R - R file containing all the necessary functions needed for making prediction


# How to use the model?

Please go to: [prediction.md](prediction.Rmd)
