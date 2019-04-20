import Control.Monad (void)
import Control.Applicative ((<$>))

import Pipes
import Pipes.Brotli
import qualified Pipes.Prelude as PP
import qualified Data.ByteString as BS

import Test.QuickCheck
import Test.QuickCheck.Monadic

roundTrip :: [BS.ByteString] -> Property
roundTrip bss = monadicIO $ do
    bss' <- run $ PP.toListM $ void $ decompress $ compress $ each bss
    monitor $ counterexample $ show bss'
    assert (BS.concat bss' == BS.concat bss)

main :: IO ()
main = quickCheck roundTrip

instance Arbitrary BS.ByteString where
    arbitrary = BS.pack <$> arbitrary
