closest <- function (SAPCA,
                     sequence,
                     PC = 1:3,
                     n  = 10){

  coords     <- SAPCA$seq.space.PCA$coordinates
  centre     <- coords[sequence,PC]
  centre.m   <- matrix(rep(centre,nrow(coords)),
                       nrow  = nrow(coords),
                       byrow = TRUE)
  distances  <- SAPCA$seq.space.PCA$coordinates[,PC]-centre.m
  rootsquare <- sqrt(rowSums(distances^2))

  sorted     <- as.matrix(rootsquare[order(rootsquare)])
  colnames(sorted) <- "distance"

  head(sorted,n)
}



as.fasta <- function(matrix,degap=FALSE,decolgap=FALSE,write=FALSE,name=NULL){

  # Remove empty columns
  if(decolgap){
    matrix<-matrix[,colMeans(matrix=="-")!=1]
  }

  # Convert alignment matrix to list of strings
  names <- paste(">",row.names(matrix),sep="")
  seqs  <- do.call("paste",c(data.frame(matrix),sep=""))

  # If just one sequence, this is how to name it
  if(is.null(dim(matrix))){
    names <- ">sequence"
    if(!is.null(name)){
      names <- paste(">",name,sep="")
    }
    seqs  <- paste(matrix,collapse="")
  }

  # Degap sequences
  if (degap){
    seqs <- gsub("-","",seqs)
  }

  # Interleave names and sequences
  ord1 <- 2*(1:length(names))-1
  ord2 <- 2*(1:length(seqs))

  # Output
  if (write==FALSE){
    cat(c(names,seqs)[order(c(ord1,ord2))], sep = "\n")
  }else{
    if (!grepl(".fa",write,ignore.case=TRUE)){
      write<-paste(write,".fa",sep="")
    }
    cat(c(names,seqs)[order(c(ord1,ord2))], sep = "\n", file = write)
  }
}



as.AAstring<-function(string, degap=FALSE){
  string <- paste(string,collapse="")
  if(degap==TRUE){
    string<-gsub("-","",string)
  }
  output <- Biostrings::AAString(string)
  output
}


as.AAstringSet<-function(MSA, degap=FALSE){
  MSA <- apply(MSA,1,paste,collapse="")
  if(degap==TRUE){
    MSA<-gsub("-","",MSA)
  }
  output <- Biostrings::AAStringSet(MSA)
  output
}



seq.MSA.add <- function(SAPCA,sequence,SAPCAname=NULL){
  MSA   <- SAPCA$numerical.alignment$MSA
  MSA2  <- as.AAstringSet(MSA,degap = TRUE)
  seqs  <- nrow(MSA)
  seq   <- as.AAstring(sequence, degap=FALSE)
  seq.d <- as.AAstring(sequence, degap=TRUE)
  BLOSUM40 <- blosum()

  aln.all <- Biostrings::pairwiseAlignment(MSA2,
                                           seq.d,
                                           substitutionMatrix = BLOSUM40,
                                           gapOpening   = 0,
                                           gapExtension = 8,
                                           scoreOnly    = TRUE)

  # Max possible similarity score
  aln.limit <- Biostrings::pairwiseAlignment(seq.d,
                                             seq.d,
                                             substitutionMatrix = BLOSUM40,
                                             gapOpening   = 0,
                                             gapExtension = 8,
                                             scoreOnly    = TRUE)

  # Similarity score as percentage of max
  aln.hit.score <- max(aln.all)/aln.limit

  # The sequence of the best matching member of the database
  aln.hit.num  <- which(aln.all==max(aln.all))[1]
  aln.hit.name <- SAPCA$numerical.alignment$seq.names[aln.hit.num]
  aln.hit.seq  <- paste(as.AAstring(MSA[aln.hit.num,],degap = 1))

  # Use "*" to indicate gaps in the best reference sequence (aln.hit)
  aln.hit <- gsub("-","*",as.AAstring(MSA[aln.hit.num,]))
  aln.add <- Biostrings::pairwiseAlignment(aln.hit,
                                           seq.d,
                                           substitutionMatrix = BLOSUM40,
                                           gapOpening   = 0,
                                           gapExtension = 8)

  # Has the new sequence introduced exrta gaps into the hit sequence alignement?
  aln.hit.orig         <- as.AAstring(MSA[aln.hit.num,])
  aln.hit.new          <- Biostrings::pattern(aln.add)
  aln.hit.seq.aln.orig <- unlist(strsplit(as.character(aln.hit.orig),""))
  aln.hit.seq.aln.new  <- unlist(strsplit(as.character(aln.hit.new),""))

  if(as.character(aln.hit.orig)!=as.character(aln.hit.new)){
    print(paste(sum(aln.hit.seq.aln.new=="-"),
                "residues of the new sequence were not alignable to the",
                SAPCAname,
                "reference MSA so were ignored"))
  }

  # Alignment addition as matrix
  aln.add.mat <- rbind(unlist(strsplit(as.character(Biostrings::pattern(aln.add)),"")),
                       unlist(strsplit(as.character(Biostrings::subject(aln.add)),"")))

  # Unmathcable resiues removed from aligned sequence
  aln.add2 <- aln.add.mat[2,][aln.add.mat[1,]!="-"]
  aln.add3 <- paste(as.AAstring(aln.add2))

  # Gaps in the hit sequence (original and newly aligned)
  gaps.orig       <- unlist(strsplit(as.character(aln.hit.orig),"[A-Z]"))
  gaps.count.orig <- nchar(gaps.orig)
  gaps.lead.orig  <- gaps.count.orig[1]
  gaps.trail.orig <- gaps.count.orig[length(gaps.count.orig)]

  gaps.new        <- unlist(strsplit(as.character(gsub("-","",aln.hit.new)),"[A-Z]"))
  gaps.count.new  <- nchar(gaps.new)
  gaps.lead.new   <- gaps.count.new[1]
  gaps.trail.new  <- gaps.count.new[length(gaps.count.new)]

  if(length(gaps.count.orig)>length(gaps.count.new)){
    gaps.count.new <- append(gaps.count.new,0)
  }

  gaps.discrep     <- suppressWarnings(rbind(gaps.count.orig,gaps.count.new))
  gaps.discrep.num <- gaps.discrep[1,]-gaps.discrep[2,]
  gaps.lead.add    <- gaps.discrep.num[1]
  gaps.trail.add   <- gaps.discrep.num[length(gaps.discrep.num)]

  # New alignment
  aln.add4  <- c(rep("-",gaps.lead.add),
                 aln.add2,
                 rep("-",gaps.trail.add))

  seq.alignable <- Biostrings::pairwiseAlignment(seq.d,
                                                 as.AAstring(aln.add3, degap=TRUE),
                                                 substitutionMatrix = BLOSUM40,
                                                 gapOpening   = 0,
                                                 gapExtension = 8)
  length(aln.add4)==ncol(MSA)

  query     <- aln.add4

  aln.final <- rbind(query,MSA)
  output    <- list(MSA             = aln.final,
                    aln.hit.name    = aln.hit.name,
                    aln.hit.seq     = aln.hit.seq,
                    aln.hit.score   = aln.hit.score,
                    aln.all.score   = aln.all/aln.limit,
                    seq.unalignable = seq.alignable)
  output
}



seq.rotate <- function(SAPCA,newseq){

  res.props  <- colnames(SAPCA$numerical.alignment$res.prop)
  prop.means <- SAPCA$numerical.alignment$prop.means
  prop.vars  <- SAPCA$numerical.alignment$prop.vars
  # Align new sequence with MSA

  # Numericise new sequence
  newseq.num <- numericise_MSA(MSA      = newseq$MSA[c("query",newseq$aln.hit.name),],
                               res.prop = SAPCA$numerical.alignment$res.prop)

  # Scale new sequnce using same scaling as SAPCA (gaps as "NA")
  newseq.scale.stack <- NULL
  for (x in 1:length(res.props)) {
    newseq.scale.stack[[res.props[x]]] <- (newseq.num$MSA.num.stack[[res.props[x]]]- prop.means[x]) /
      sqrt(prop.vars[x])
  }

  # Reflow into single wide matrix
  newseq.scale.wide <- newseq.scale.stack[[1]]
  for (x in 2:length(res.props)) {
    newseq.scale.wide <- cbind(newseq.scale.wide, newseq.scale.stack[[res.props[x]]])
  }

  # Replace gaps (currently "NA") with column average of the scaled SAPCA
  # Create na.colmean function
  gapvalues  <- colMeans(SAPCA$numerical.alignment$MSA.scale.wide)
  na.replace <- function(x,y){
    x[is.na(x)] <- y
    x
  }
  newseq.scale.wide.g <- NULL
  for(i in 1:ncol(newseq.scale.wide)){
    newseq.scale.wide.g <- cbind(newseq.scale.wide.g,
                                 na.replace(newseq.scale.wide[,i],gapvalues[i]))
  }

  # Rotate scaled sequence into same space as SAPCA
  newseq.rot <- scale(newseq.scale.wide.g,
                      SAPCA$seq.space.PCA$centre,
                      SAPCA$seq.space.PCA$scale) %*% SAPCA$seq.space.PCA$loadings

  # Output
  output <- list(seq       = newseq,
                 seq.num   = newseq.num$MSA.num.wide,
                 seq.scale = newseq.scale.wide.g,
                 seq.rot   = newseq.rot)
  output
}



seq.clust.add <- function(SAPCA,newseq.r){

  SAPCA.c  <- mclustrev(SAPCA)
  newseq.c <- mclust::predict.Mclust(SAPCA.c,newseq.r$seq.rot[,SAPCA$call$clusterPCs])
  newseq.c
}



mclustrev <- function(SAPCA){
  output <- SAPCA$seq.space.clusters$other

  output$classification <- SAPCA$seq.space.clusters$classification
  output$G              <- SAPCA$seq.space.clusters$optimal
  output$z              <- SAPCA$seq.space.clusters$likelihoods

  class(output) <- "Mclust"
  output
}



seq.SAPCA.add <- function (SAPCA,newseq.r,newseq.c){
  output <- SAPCA
  output$numerical.alignment$seq.names      <- rownames(newseq.r$seq$MSA)
  output$numerical.alignment$MSA            <- newseq.r$seq$MSA
  output$numerical.alignment$MSA.num.wide   <- rbind(newseq.r$seq.num[1,],
                                                     SAPCA$numerical.alignment$MSA.num.wide)
  output$numerical.alignment$MSA.scale.wide <- rbind(newseq.r$seq.scale[1,],
                                                     SAPCA$numerical.alignment$MSA.scale.wide)
  output$numerical.alignment$MSA.num.stack  <- NULL
  output$numerical.alignment$MSA.scale.stack<- NULL

  output$seq.space.PCA$coordinates          <- rbind(newseq.r$seq.rot[1,],
                                                     SAPCA$seq.space.PCA$coordinates)
  output$seq.space.clusters$likelihoods     <- rbind(newseq.c$z[1,],
                                                     SAPCA$seq.space.clusters$likelihoods)
  output$seq.space.clusters$classification  <- c(newseq.c$classification[1],
                                                 SAPCA$seq.space.clusters$classification)

  rownames(output$numerical.alignment$MSA.num.wide)[1]   <- "query"
  rownames(output$numerical.alignment$MSA.scale.wide)[1] <- "query"
  rownames(output$seq.space.PCA$coordinates)[1]          <- "query"
  rownames(output$seq.space.clusters$likelihoods)[1]     <- "query"

  output
}



seq.add.full <- function (SAPCA,sequence,SAPCAname=NULL){

  newseq   <- seq.MSA.add(SAPCA,sequence,SAPCAname)
  newseq.r <- seq.rotate(SAPCA,newseq)
  newseq.c <- seq.clust.add(SAPCA,newseq.r)
  SAPCA2   <- seq.SAPCA.add(SAPCA,newseq.r,newseq.c)

  SAPCA2
}





percent <- function(x, digits = 1, format = "f", ...) {
  paste0(formatC(100 * x, format = format, digits = digits, ...), "%")
}


