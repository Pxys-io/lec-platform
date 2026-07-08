import { useEffect, useRef } from 'react'
import Hls from 'hls.js'
import { getToken } from '../lib/api'

interface VideoPlayerProps {
  manifestUrl: string
  className?: string
}

export default function VideoPlayer({ manifestUrl, className = "" }: VideoPlayerProps) {
  const videoRef = useRef<HTMLVideoElement>(null)

  useEffect(() => {
    const video = videoRef.current
    if (!video) return

    let hls: Hls | null = null
    const token = getToken()

    if (Hls.isSupported()) {
      hls = new Hls({
        xhrSetup: (xhr) => {
          if (token) {
            xhr.setRequestHeader('Authorization', `Bearer ${token}`)
          }
        }
      })
      hls.loadSource(manifestUrl)
      hls.attachMedia(video)
    } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
      video.src = manifestUrl
    }

    return () => {
      if (hls) {
        hls.destroy()
      }
    }
  }, [manifestUrl])

  return (
    <video
      ref={videoRef}
      className={`w-full aspect-video bg-black rounded-lg ${className}`}
      controls
      playsInline
    />
  )
}
