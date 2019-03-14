module Lib where

import Data.Maybe (catMaybes)
import Control.Monad (forM)
import Network.Socket
import Control.Monad (replicateM)
import Control.Concurrent (threadDelay)
import Control.Monad (forever)
import Control.Distributed.Process
import Control.Distributed.Process.Node (runProcess, forkProcess, initRemoteTable, closeLocalNode)
import Network.Transport.TCP (createTransport, defaultTCPParameters)
import Control.Distributed.Process.Backend.SimpleLocalnet

import Types

-- replyBack :: (ProcessId, String) -> Process ()
-- replyBack (sender, msg) = send sender msg

heartbeatMsg :: String -> Process ()
heartbeatMsg msg = say $ "handling " ++ msg

votedFor :: VoteFor -> Process ()
votedFor msg = liftIO $ print "Got vote" >>= return

voteStarted :: StartVote -> Process ()
voteStarted (StartVote nId) = nsendRemote nId "main" VoteFor

-- An implicit state machine, doesn't protect against calling into bad states.
-- TODO: Use types to enforce proper state transitions
-- TODO: Separate out pure portions
runRaft :: RaftState -> RaftEvent -> Process RaftState
runRaft (Follower stateInfo) HeartBeat = followerLoop stateInfo
runRaft (Candidate stateInfo) Timeout = candidateLoop stateInfo
runRaft (Leader stateInfo) VotedIn = do
    liftIO $ print "Leader state: unimplemented"
    receiveTimeout (1000*100) []
    die "Leader not implemented"

candidateLoop :: RaftStateInfo -> Process RaftState
candidateLoop state@(RaftStateInfo selfPid backend) = do
    liftIO $ print "Candidate state"

    peers <- liftIO $ findPeers backend 1000000
    let otherPeers = filter (\x -> x /= (processNodeId selfPid)) peers
    liftIO . print $ show otherPeers
    mapM_ (\x -> nsendRemote x "main" (StartVote $ processNodeId selfPid)) otherPeers
    recieved <- forM otherPeers . const $ receiveTimeout (1000 * 1000) [match votedFor]

    let numPeersNeeded = length otherPeers
    let numGot = length $ catMaybes recieved
    liftIO . print $ "needed: " ++ show numPeersNeeded
    liftIO . print $ "got   : " ++ (show numGot)

    if numGot >= numPeersNeeded
       then runRaft (Leader state) VotedIn
       else runRaft (Candidate state) Timeout

followerLoop :: RaftStateInfo -> Process RaftState
followerLoop state@(RaftStateInfo selfPid backend) = do
    liftIO $ print "Follower state"
    received <- receiveTimeout (5 * 1000 * 1000) [match heartbeatMsg, match voteStarted]
    case received of
         Just msg -> runRaft (Follower state) HeartBeat
         Nothing -> runRaft (Candidate state) Timeout

someFunc :: ServiceName -> IO ()
someFunc serviceName = do
    -- Right t <- createTransport "127.0.0.1" "10501" (\p -> ("","")) defaultTCPParameters
    backend <- initializeBackend "127.0.0.1" serviceName initRemoteTable
    -- nodes <- replicateM 3 $ newLocalNode backend
    node <- newLocalNode backend
    -- remotes <- mapM (flip forkProcess echo) nodes
    runProcess node $ do
        selfPid <- getSelfPid
        register "main" selfPid
        runRaft (Follower (RaftStateInfo selfPid backend)) HeartBeat
        return ()
