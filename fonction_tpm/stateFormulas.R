
stateFormulas<-function(formula,nbStates,spec="state",angleMean=FALSE,data=NULL){
  
  Terms <- terms(formula, specials = c(paste0(spec,1:nbStates),"cosinor","angleFormula"))
  if(any(grepl("angleStrength\\(",attr(Terms,"term.labels")))) stop("'angleStrength' is defunct in momentuHMM >=1.4.2. Please use 'angleFormula' instead")
  if(any(attr(Terms,"order")>1)){
    if(any(grepl("angleFormula\\(",attr(Terms,"term.labels")[attr(Terms,"order")>1]))) stop("interactions with angleFormula are not allowed")
  }
  
  stateFormula<-list()
  if(length(unlist(attr(Terms,"specials"))) | angleMean){
    varnames <- attr(Terms,"term.labels")
    mainpart <- varnames
    cosInd <- survival::untangle.specials(Terms,"cosinor",order=1:10)$terms
    if(length(cosInd) & angleMean) stop("cosinor models are not supported for angle means")
    angInd <- survival::untangle.specials(Terms,"angleFormula",order=1:10)$terms
    if(length(angInd) & !angleMean) stop("angleFormula models are only allowed for angle means")
    stateInd <- numeric()
    for(j in 1:nbStates){
      tmpInd <- survival::untangle.specials(Terms,paste0(spec,j),order=1)$terms
      if(length(tmpInd)) stateInd<-c(stateInd,tmpInd)
    }
    if(length(cosInd) | length(angInd) | length(stateInd)){
      mainpart <- varnames[-c(cosInd,angInd,stateInd)]
    }
    if(angleMean & length(mainpart)){
      tmpmainpart <- mainpart
      mainpart <- character()
      if(any(grepl("cos",tmpmainpart)) | any(grepl("sin",tmpmainpart))) stop("sorry, the strings 'cos' and 'sin' are reserved and cannot appear in mean angle formulas and/or covariate names")
      for(j in 1:length(tmpmainpart)){
        mainpart <- c(mainpart,paste0(c("sin","cos"),"(",tmpmainpart[j],")"))
      }
    }
    for(j in varnames[cosInd])
      mainpart<-c(mainpart,paste0(gsub("cosinor","cosinorCos",j)),paste0(gsub("cosinor","cosinorSin",j)))
    if(length(angInd)){
      stmp <- prodlim::strip.terms(Terms[attr(Terms,"specials")$angleFormula],specials="angleFormula",arguments=list(angleFormula=list("strength"=NULL,"by"=NULL)))
      if(any(grepl("cos",attr(stmp,"term.labels"))) | any(grepl("sin",attr(stmp,"term.labels")))) stop("sorry, the strings 'cos' and 'sin' are reserved and cannot appear in mean angle formulas and/or covariate names")
      for(jj in attr(stmp,"term.labels")){
        if(is.null(attr(stmp,"stripped.arguments")$angleFormula[[jj]]$strength)){
          tmpForm <- ~ - 1
          strengthInd <- FALSE
        }
        else {
          if(!is.na(suppressWarnings(as.numeric((attr(stmp,"stripped.arguments")$angleFormula[[jj]]$strength))))) stop("angleFormula has invalid strength argument")
          tmpForm <- as.formula(paste0("~-1+",attr(stmp,"stripped.arguments")$angleFormula[[jj]]$strength))
          if(any(attr(terms(tmpForm),"order")>1)) stop("angleFormula strength argument for ",jj," cannot include term interactions; use the 'by' argument")
          strengthInd <- TRUE
        }
        group <- attr(stmp,"stripped.arguments")$angleFormula[[jj]]$by
        if(!is.null(data)){
          DMterms <- attr(terms(tmpForm),"term.labels")
          factorterms<-names(data)[unlist(lapply(data,is.factor))]
          factorcovs<-paste0(rep(factorterms,times=unlist(lapply(data[factorterms],nlevels))),unlist(lapply(data[factorterms],levels)))
          for(cov in DMterms){
            form<-formula(paste("~",cov))
            varform<-all.vars(form)
            if(any(varform %in% factorcovs)){
              factorvar<-factorcovs %in% varform
              tmpcov<-rep(factorterms,times=unlist(lapply(data[factorterms],nlevels)))[which(factorvar)]
              tmpcovj <- cov
              for(j in 1:length(tmpcov)){
                tmpcovj <- gsub(factorcovs[factorvar][j],tmpcov[j],tmpcovj)
              }
              form <- formula(paste("~ 0 + ",tmpcovj))
            }
            if(strengthInd){
              if(any(model.matrix(form,data)<0)) stop(attr(stmp,"stripped.arguments")$angleFormula[[jj]]$strength," must be >=0 in order to be used in angleFormula")
              if(any(unlist(lapply(data[all.vars(form)],function(x) inherits(x,"factor"))))) stop("angleFormula strength argument cannot be a factor; use the 'by' argument for factors")
            }
          }
          if(!is.null(group)){
            form<-formula(paste("~",group))
            varform<-all.vars(form)
            if(any(varform %in% factorcovs)){
              factorvar<-factorcovs %in% varform
              varform<-rep(factorterms,times=unlist(lapply(data[factorterms],nlevels)))[which(factorvar)]
            }
            if(any(!(varform %in% names(data)))) stop("angleFormula 'by' argument ",varform[which(!(varform %in% names(data)))]," not found in data")
            if(any(!unlist(lapply(data[varform],function(x) inherits(x,"factor"))))) stop("angleFormula 'by' argument must be of class factor")
          }
        }
        
        if(!is.null(group)) group <- paste0(group,":")
        mainpart<-c(mainpart,paste0(group,ifelse(strengthInd,paste0(attr(stmp,"stripped.arguments")$angleFormula[[jj]]$strength,":"),""),c("sin","cos"),"(",jj,")"))
      }
    }
    
    for(j in 1:nbStates){
      tmplabs<-attr(Terms,"term.labels")[attr(Terms,"specials")[[paste0(spec,j)]]]
      if(length(tmplabs)){
        tmp<- terms(as.formula(paste("~",substr(tmplabs,nchar(paste0(spec,j))+1,nchar(tmplabs)),collapse="+")),specials=c("cosinor","angleFormula"))
        
        tmpnames<-attr(tmp,"term.labels")
        if(any(grepl("angleStrength\\(",tmpnames))) stop("'angleStrength' is defunct in momentuHMM >=1.4.2. Please use 'angleFormula' instead")
        if(any(attr(tmp,"order")>1)){
          if(any(grepl("angleFormula\\(",tmpnames[attr(tmp,"order")>1]))) stop("interactions with angleFormula are not allowed")
        }
        mp<-tmpnames
        if(!is.null(unlist(attr(tmp,"specials"))) | angleMean){
          cosInd <- survival::untangle.specials(tmp,"cosinor",order=1:10)$terms
          if(length(cosInd) & angleMean) stop("cosinor models are not supported for angle means")
          angInd <- survival::untangle.specials(tmp,"angleFormula",order=1:10)$terms
          if(length(angInd) & !angleMean) stop("angleFormula models are only allowed for angle means")
          if(length(cosInd) | length(angInd)){
            mp <- c(tmpnames[-c(cosInd,angInd)])
          }
          if(angleMean & length(mp)){
            tmpmp <- mp
            mp <- character()
            if(any(grepl("cos",tmpmp)) | any(grepl("sin",tmpmp))) stop("sorry, the strings 'cos' and 'sin' are reserved and cannot appear in mean angle formulas and/or covariate names")
            for(jj in 1:length(tmpmp)){
              mp <- c(mp,paste0(c("sin","cos"),"(",tmpmp[jj],")"))
            }
          }
          for(i in tmpnames[cosInd])
            mp<-c(mp,paste0(gsub("cosinor","cosinorCos",i)),paste0(gsub("cosinor","cosinorSin",i)))
          if(length(angInd)){
            stmp <- prodlim::strip.terms(tmp[attr(tmp,"specials")$angleFormula],specials="angleFormula",arguments=list(angleFormula=list("strength"=NULL,"by"=NULL)))
            if(any(grepl("cos",attr(stmp,"term.labels"))) | any(grepl("sin",attr(stmp,"term.labels")))) stop("sorry, the strings 'cos' and 'sin' are reserved and cannot appear in mean angle formulas and/or covariate names")
            for(jj in attr(stmp,"term.labels")){
              if(is.null(attr(stmp,"stripped.arguments")$angleFormula[[jj]]$strength)){
                tmpForm <- ~ - 1
                strengthInd <- FALSE
              }
              else {
                if(!is.na(suppressWarnings(as.numeric((attr(stmp,"stripped.arguments")$angleFormula[[jj]]$strength))))) stop("angleFormula has invalid strength argument")
                tmpForm <- as.formula(paste0("~-1+",attr(stmp,"stripped.arguments")$angleFormula[[jj]]$strength))
                if(any(attr(terms(tmpForm),"order")>1)) stop("angleFormula strength argument cannot include term interactions; use the 'by' argument")
                strengthInd <- TRUE
              }
              group <- attr(stmp,"stripped.arguments")$angleFormula[[jj]]$by
              if(!is.null(data)){
                if(strengthInd){
                  if(any(model.matrix(tmpForm,data)<0)) stop(attr(stmp,"stripped.arguments")$angleFormula[[jj]]$strength," must be >=0 in order to be used in angleFormula")
                  if(inherits(data[[attr(stmp,"stripped.arguments")$angleFormula[[jj]]$strength]],"factor")) stop("angleFormula strength argument cannot be a factor; use the 'by' argument for factors")
                }
                if(!is.null(group)){
                  varform <- all.vars(as.formula(paste0("~",group)))
                  if(any(!(varform %in% names(data)))) stop("angleFormula 'by' argument ",varform[which(!(varform %in% names(data)))]," not found in data")
                  if(any(!unlist(lapply(data[varform],function(x) inherits(x,"factor"))))) stop("angleFormula 'by' argument must be of class factor")
                }
              }
              if(!is.null(group)) group <- paste0(group,":")
              mp<-c(mp,paste0(group,ifelse(strengthInd,paste0(attr(stmp,"stripped.arguments")$angleFormula[[jj]]$strength,":"),""),c("sin","cos"),"(",jj,")"))
            }
          }
        }
      } else {
        tmp <- Terms
        mp <- character()
      }
      stateFormula[[j]]<-as.formula(paste("~",paste(c(attr(tmp,"intercept"),mainpart,mp),collapse = " + "),collapse=" + "))
    }
  } else {
    for(j in 1:nbStates){
      stateFormula[[j]] <- formula
    }
  }
  stateFormula
}
