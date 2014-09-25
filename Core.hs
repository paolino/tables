data Info -- what's this ?

data Event = Event IndexEvent Time Info
data Episode = Episode IndexEpisode IndexEvent Time Info

data Context = CEvent Event | CEpisode Event Episode 

data Room = Room IndexRoom User Info

data Notification 
  = Shout User Context Info
  | CanChat Room
  | Can'tChat IndexRoom
  | Banned
  | EventRoll Event Time
  | EventStop Event
  | Episode Event Episode
