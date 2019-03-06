module Types where

import Control.Distributed.Process
import Control.Distributed.Process.Backend.SimpleLocalnet

data RaftStateInfo = RaftStateInfo {
    pid :: ProcessId,
    backend :: Backend
}
data RaftState = Follower RaftStateInfo | Candidate RaftStateInfo | Leader RaftStateInfo
data RaftEvent = HeartBeat | Timeout | VotedIn | OtherLeader

