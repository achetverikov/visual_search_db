library('mongolite')
m_counters <- mongo('counters', db = "vissearch")
m_authors <- mongo('authors', db = "vissearch")
m_equipment <- mongo('equipment', db = "vissearch")
m_exp <- mongo('experiments', db = "vissearch")
m_subj <- mongo('subjects', db = "vissearch")
m_blocks <- mongo('blocks', db = "vissearch")
m_trials <- mongo('trials', db = "vissearch")
m_stims <- mongo('stimuli', db = "vissearch")


getNextSequence <- function (name, n=1) {
  m_counters$update(sprintf('{ "_id": "%s" }', name), sprintf('{ "$inc": { "seq": %i } }',n))
  res<-m_counters$find(sprintf('{ "_id": "%s" }', name))
  (res[,1]-n+1):res[,1]
}