import { useEffect, useRef, useState } from 'react'
import Hls from 'hls.js'
import { getToken } from '../lib/api'

interface VideoPlayerProps {
  manifestUrl: string
  className?: string
  onError?: (message: string) => void
}

export default function VideoPlayer({ manifestUrl, className = "", onError }: VideoPlayerProps) {
  const videoRef = useRef<HTMLVideoElement>(null)
  const [fatalError, setFatalError] = useState<string | null>(null)
  const [retryCount, setRetryCount] = useState(0)

  useEffect(() => {
    const video = videoRef.current
    if (!video) return

    setFatalError(null)
    let hls: Hls | null = null
    let cancelled = false

    const reportError = (message: string) => {
      if (!cancelled) {
        setFatalError(message)
        onError?.(message)
      }
    }

    if (Hls.isSupported()) {
      hls = new Hls({
        enableWorker: true,
        // fMP4 (MUX) + AES-128 + watermark discontinuities need patient retries
        manifestLoadingMaxRetry: 3,
        levelLoadingMaxRetry: 4,
        fragLoadingMaxRetry: 4,
        manifestLoadingRetryDelay: 1000,
        fragLoadingRetryDelay: 1000,
        // Don't stall forever on a bad break-screen/overlay fragment
        fragLoadingMaxRetryTimeout: 64000,
        maxBufferLength: 30,
        maxMaxBufferLength: 120,
        xhrSetup: (xhr, url) => {
          // Auth is only needed for our proxy (playlist/key/watermark URLs).
          // R2 segment URLs are public (content is AES-encrypted) - never leak
          // the JWT to the CDN by sending it there.
          if (url.includes('/api/v1/videos/proxy') || url.startsWith('/api/') || url.startsWith(window.location.origin)) {
            const token = getToken() // read fresh per request, not at mount
            if (token) {
              xhr.setRequestHeader('Authorization', `Bearer ${token}`)
            }
          }
        },
      })
      hls.on(Hls.Events.ERROR, (_event, data) => {
        if (!data.fatal) return
        if (data.type === Hls.ErrorTypes.MEDIA_ERROR) {
          // Codec/discontinuity hiccup (e.g. audio track changes across a
          // watermark break) - usually recoverable without re-fetching.
          try {
            hls?.recoverMediaError()
            return
          } catch {
            // fall through to fatal
          }
        }
        reportError(
          data.details || (data.type === Hls.ErrorTypes.NETWORK_ERROR ? 'Network error loading video' : 'Video playback error')
        )
      })
      hls.loadSource(manifestUrl)
      hls.attachMedia(video)
    } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
      // Safari native HLS can't set headers - authenticate via ?token=
      // (main-server playlist + proxy endpoints accept it).
      const token = getToken()
      const needsToken = token && !/[?&]token=/.test(manifestUrl)
      video.src = needsToken
        ? `${manifestUrl}${manifestUrl.includes('?') ? '&' : '?'}token=${encodeURIComponent(token)}`
        : manifestUrl
      const onNativeError = () => {
        const mediaError = video.error
        reportError(mediaError ? `Native playback error (code ${mediaError.code})` : 'Native playback error')
      }
      video.addEventListener('error', onNativeError)
      return () => {
        cancelled = true
        video.removeEventListener('error', onNativeError)
        video.removeAttribute('src')
        video.load()
      }
    } else {
      reportError('HLS is not supported in this browser')
    }

    return () => {
      cancelled = true
      if (hls) {
        hls.destroy()
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [manifestUrl, retryCount])

  if (fatalError) {
    return (
      <div className={`w-full aspect-video bg-black rounded-lg flex flex-col items-center justify-center gap-3 text-center px-6 ${className}`}>
        <p className="text-sm text-red-400 font-medium">Playback failed</p>
        <p className="text-xs text-gray-400 break-all">{fatalError}</p>
        <button
          onClick={() => setRetryCount((c) => c + 1)}
          className="px-4 py-2 bg-white/10 hover:bg-white/20 text-white rounded-lg text-sm font-medium transition-colors"
        >
          Retry
        </button>
      </div>
    )
  }

  return (
    <video
      ref={videoRef}
      className={`w-full aspect-video bg-black rounded-lg ${className}`}
      controls
      playsInline
    />
  )
}
