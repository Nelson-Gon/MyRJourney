nomsg<-suppressMessages
nomsg(library(tidyverse))
nomsg(library(caretEnsemble))
nomsg(library(caret))
nomsg(library(RANN))
nomsg(library(mice))
#Start working on data cleaning
training<-read.csv("train.csv")
training<-as.tibble(training)
#Find missing data
training %>% 
  map_dbl(~sum(is.na(.x))) %>% 
  sort(decreasing = T)
#Change levelsof all categorical data in this crude way. NA is not missing data
newtrain<-training %>% 
 mutate(GarageType=fct_explicit_na(GarageType,na_level = "No"),
        Alley=fct_explicit_na(Alley,na_level = "No"),
        Fence=fct_explicit_na(Fence,na_level = "No"),
        FireplaceQu=fct_explicit_na(FireplaceQu,na_level = "No"),
        GarageFinish=fct_explicit_na(GarageFinish,na_level = "No"),
        GarageQual=fct_explicit_na(GarageQual,na_level = "No"),
        GarageCond=fct_explicit_na(GarageCond,na_level = "No"),
        BsmtExposure=fct_explicit_na(BsmtExposure,na_level = "No"),
        BsmtFinType2=fct_explicit_na(BsmtFinType2,na_level = "No"),
        BsmtQual=fct_explicit_na(BsmtQual,na_level = "No"),
        MasVnrType=fct_explicit_na(MasVnrType,na_level = "No"),
        Electrical=fct_explicit_na(Electrical,na_level = "No"))
#Find remaining NAs
newtrain %>% 
  map_dbl(~sum(is.na(.x))) %>% 
  sort(decreasing = T)
levels(newtrain$GarageYrBlt)
#Change levels PoolQc and these others because NA is not missing data
 newtrain<-newtrain %>% 
   mutate(PoolQC=fct_explicit_na(PoolQC,na_level = "No"),
          MiscFeature=fct_explicit_na(MiscFeature,na_level = "No"),
          BsmtCond=fct_explicit_na(BsmtCond,na_level = "No"),
          BsmtFinType1=fct_explicit_na(BsmtFinType1,na_level = "No")) %>% 
          select(-Id)
 #Find remain missing data
 newtrain %>% 
   map_dbl(~sum(is.na(.x))) %>% 
   sort(decreasing = T)
 #Impute missing data with mice
 exclude<-c("GarageYrBlt","MasVnrArea")
 include<-setdiff(names(newtrain),exclude)
 set.seed(233)
 newtrain1<-newtrain[include]
 #Impute missing data
 newtrain_imp<-mice(newtrain1,m=1,method = "cart",printFlag = F)
 newtrain11<-complete(newtrain_imp)
 newtrain11 %>% 
   map_dbl(~sum(is.na(.x))) %>% 
   sort(decreasing = T)
 #Great, There is no more missing data
#Train
trainme<-createDataPartition(newtrain11$SalePrice,p=0.8,list=F)
validateme<-newtrain11[-trainme,]
trainme<-newtrain11[trainme,]
control<-trainControl(method ="cv",number=10)
metric<-"RMSE"
set.seed(233)
fit.svm<-train(SalePrice~.,data=trainme,method="svmRadial",trControl=control,metric=metric)
fit.knn<-train(SalePrice~.,data=trainme,method="knn",trControl=control,metric=metric)
fit.gbm<-train(SalePrice~.,data=trainme,method="gbm",trControl=control,metric=metric)
#.....
result<-resamples(list(svm=fit.svm,knn=fit.knn,gbm=fit.gbm))
dotplot(result)
#Predict on validation set
predval<-predict(fit.gbm,validateme)
#Load test data
testing<-read.csv("test.csv")
#Remove NAs in a very crude way. Not suitable for extremely large data. Use a function instead
testing<-testing %>% 
  mutate(PoolQC=fct_explicit_na(PoolQC,na_level = "No"),
         MiscFeature=fct_explicit_na(MiscFeature,na_level = "No"),
         BsmtCond=fct_explicit_na(BsmtCond,na_level = "No"),
         BsmtFinType1=fct_explicit_na(BsmtFinType1,na_level = "No"),
         GarageType=fct_explicit_na(GarageType,na_level = "No"),
         Alley=fct_explicit_na(Alley,na_level = "No"),
         Fence=fct_explicit_na(Fence,na_level = "No"),
         FireplaceQu=fct_explicit_na(FireplaceQu,na_level = "No"),
         GarageFinish=fct_explicit_na(GarageFinish,na_level = "No"),
         GarageQual=fct_explicit_na(GarageQual,na_level = "No"),
         GarageCond=fct_explicit_na(GarageCond,na_level = "No"),
         BsmtExposure=fct_explicit_na(BsmtExposure,na_level = "No"),
         BsmtFinType2=fct_explicit_na(BsmtFinType2,na_level = "No"),
         BsmtQual=fct_explicit_na(BsmtQual,na_level = "No"),
         MasVnrType=fct_explicit_na(MasVnrType,na_level = "No"),
         Electrical=fct_explicit_na(Electrical,na_level = "No"))
#Impute missing data
#Preprocess the data
set.seed(233)
exclude<-c("GarageYrBlt","MasVnrArea","Alley")
include<-setdiff(names(testing),exclude)
set.seed(233)
newtest1<-testing[include1]
#Impute missing data
newtest_imp<-mice(testing,m=3,method = "cart",printFlag = F)
newtest11<-complete(newtest_imp)
#Check for missing values 
newtest11 %>% 
  map_dbl(~sum(is.na(.x))) %>% 
  sort(decreasing = T)
#Predict as we have 2 more missing values. replace these with 0
predictedme<-predict(fit.gbm,newtest11,na.action = na.pass)
resultme<-newtest11 %>% 
  mutate(SalePrice=predictedme) %>% 
  mutate_all(funs(replace(.,is.na(.),0))) %>% 
  select(Id,SalePrice)

write.csv(resultme,"mysubm.csv",row.names = F)