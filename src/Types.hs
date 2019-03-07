{-# LANGUAGE DeriveDataTypeable     #-}
{-# LANGUAGE DeriveGeneric          #-}

module Types where

import Control.Distributed.Process
import Control.Distributed.Process.Backend.SimpleLocalnet

import GHC.Generics
import Data.Binary
import Data.Typeable

data RaftStateInfo = RaftStateInfo {
    pid :: ProcessId,
    backend :: Backend
}
data RaftState = Follower RaftStateInfo | Candidate RaftStateInfo | Leader RaftStateInfo
data RaftEvent = HeartBeat | Timeout | VotedIn | OtherLeader

data StartVote = StartVote NodeId
    deriving (Generic, Typeable, Show)

instance Binary StartVote where

data VoteFor = VoteFor
    deriving (Generic, Typeable, Show)

instance Binary VoteFor where

