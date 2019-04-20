{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE Trustworthy #-}

-- |
-- Module      : Pipes.Brotli
-- Copyright   : © 2016 Herbert Valerio Riedel
--
-- Maintainer  : hvr@gnu.org
--
-- Compression and decompression of data streams in the \"Brotli\" format (<https://tools.ietf.org/html/rfc7932 RFC7932>)
--
module Pipes.Brotli
    ( -- * Simple interface
      compress
    , decompress

      -- * Extended interface
      -- ** Compression
    , compressWith

    , Brotli.defaultCompressParams
    , Brotli.CompressParams
    , Brotli.compressLevel
    , Brotli.compressWindowSize
    , Brotli.compressMode
    , Brotli.compressSizeHint
    , Brotli.CompressionLevel(..)
    , Brotli.CompressionWindowSize(..)
    , Brotli.CompressionMode(..)

      -- ** Decompression
    , decompressWith

    , Brotli.defaultDecompressParams
    , Brotli.DecompressParams
    , Brotli.decompressDisableRingBufferReallocation

    ) where

import Pipes
import Data.ByteString (ByteString)
import qualified Data.ByteString as BS
import qualified Codec.Compression.Brotli as Brotli

-- | Decompress a 'ByteString'.
decompress :: forall m r. MonadIO m
           => Producer ByteString m r
           -> Producer ByteString m (Producer ByteString m r)
decompress = decompressWith Brotli.defaultDecompressParams

-- | Decompress a 'ByteString' with a given set of 'Brotli.DecompressParams'.
decompressWith :: forall m r. MonadIO m
               => Brotli.DecompressParams
               -> Producer ByteString m r
               -> Producer ByteString m (Producer ByteString m r)
decompressWith params prod0 = liftIO (Brotli.decompressIO params) >>= go prod0
  where
    go :: Producer ByteString m r
       -> Brotli.DecompressStream IO
       -> Producer ByteString m (Producer ByteString m r)
    go prod s@(Brotli.DecompressInputRequired more) = do
        mx <- lift $ next prod
        case mx of
          Right (x, prod')
            | BS.null x    -> go prod' s
            | otherwise    -> liftIO (more x) >>= go prod'
          Left r           -> liftIO (more BS.empty) >>= go (return r)
    go prod (Brotli.DecompressOutputAvailable output cont) = do
        yield output
        liftIO cont >>= go prod
    go prod (Brotli.DecompressStreamEnd leftover) =
        return (yield leftover >> prod)
    go _prod (Brotli.DecompressStreamError ecode) =
        fail $ "Pipes.Brotli.decompress: error (" ++ Brotli.showBrotliDecoderErrorCode ecode ++ ")"

-- | Compress a 'ByteString'.
compress :: forall m r. MonadIO m
         => Producer ByteString m r
         -> Producer ByteString m r
compress = compressWith Brotli.defaultCompressParams

-- | Compress a 'ByteString' with a given set of 'Brotli.CompressParams'.
compressWith :: forall m r. MonadIO m
             => Brotli.CompressParams
             -> Producer ByteString m r
             -> Producer ByteString m r
compressWith params prod0 = liftIO (Brotli.compressIO params) >>= go prod0
  where
    go :: Producer ByteString m r
       -> Brotli.CompressStream IO
       -> Producer ByteString m r
    go prod s@(Brotli.CompressInputRequired _flush more) = do
        mx <- lift $ next prod
        case mx of
          Right (x, prod')
            | BS.null x    -> go prod' s
            | otherwise    -> liftIO (more x) >>= go prod'
          Left r           -> liftIO (more BS.empty) >>= go (return r)
    go prod (Brotli.CompressOutputAvailable output cont) = do
        yield output
        liftIO cont >>= go prod
    go prod Brotli.CompressStreamEnd =
        prod
