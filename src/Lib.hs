module Lib where

import Control.Monad (replicateM)
import Control.Concurrent (threadDelay)
import Control.Monad (forever)
import Control.Distributed.Process
import Control.Distributed.Process.Node (runProcess, forkProcess, initRemoteTable, closeLocalNode)
import Network.Transport.TCP (createTransport, defaultTCPParameters)
import Control.Distributed.Process.Backend.SimpleLocalnet

replyBack :: (ProcessId, String) -> Process ()
replyBack (sender, msg) = send sender msg

logMessage :: String -> Process ()
logMessage msg = say $ "handling " ++ msg

echo = do
      receiveWait [match logMessage, match replyBack]


someFunc :: IO ()
someFunc = do
  -- Right t <- createTransport "127.0.0.1" "10501" (\p -> ("","")) defaultTCPParameters
  backend <- initializeBackend "127.0.0.1" "10511" initRemoteTable
  nodes <- replicateM 3 $ newLocalNode backend
  node <- newLocalNode backend
  remotes <- mapM ((flip forkProcess) echo) nodes
  runProcess node $ do
    -- Spawn another worker on the local node
    echoPid <- spawnLocal $ forever $ echo

    -- The `say` function sends a message to a process registered as "logger".
    -- By default, this process simply loops through its mailbox and sends
    -- any received log message strings it finds to stderr.

    say "send some messages!"
    send echoPid "hello"
    mapM ((flip send) "hello2") remotes
    self <- getSelfPid
    mapM ((flip send) (self, "hello")) remotes
    send echoPid (self, "hello")

    -- `expectTimeout` waits for a message or times out after "delay"
    m <- expectTimeout 1000000
    case m of
      -- Die immediately - throws a ProcessExitException with the given reason.
      Nothing  -> die "nothing came back!"
      Just s -> say $ "got " ++ s ++ " back!"

    -- Without the following delay, the process sometimes exits before the messages are exchanged.
    liftIO $ threadDelay 2000000
  -- mapM_ closeLocalNode nodes
