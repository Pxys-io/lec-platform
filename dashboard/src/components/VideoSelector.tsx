import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { api } from '../lib/api'
import { Search, Video, X, Check, Loader2 } from 'lucide-react'

interface Video {
  id: string
  title: string
  status: string
  folder: string
  streaming_mode: string
  duration_seconds: number | null
}

interface VideoSelectorProps {
  selectedId: string | null
  onSelect: (id: string | null) => void
  onClose: () => void
}

export default function VideoSelector({ selectedId, onSelect, onClose }: VideoSelectorProps) {
  const [search, setSearch] = useState('')

  const { data: videos, isLoading } = useQuery<Video[]>({
    queryKey: ['manage-videos'],
    queryFn: () => api.get('/videos/manage'),
  })

  const filtered = videos?.filter((v) =>
    v.id.toLowerCase().includes(search.toLowerCase()) ||
    v.title?.toLowerCase().includes(search.toLowerCase())
  )

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50">
      <div className="bg-white rounded-2xl w-full max-w-2xl overflow-hidden shadow-2xl flex flex-col max-h-[80vh]">
        <div className="flex items-center justify-between p-4 border-b shrink-0">
          <h2 className="text-lg font-bold">Select Video from Pool</h2>
          <button onClick={onClose} className="p-1 hover:bg-gray-100 rounded-lg">
            <X className="h-5 w-5 text-gray-400" />
          </button>
        </div>

        <div className="p-4 border-b shrink-0">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
            <input
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="w-full pl-10 pr-4 py-2 rounded-lg border border-border bg-surface text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
              placeholder="Search videos by title or ID..."
              autoFocus
            />
          </div>
        </div>

        <div className="flex-1 overflow-y-auto p-4 space-y-2">
          {isLoading ? (
            <div className="flex flex-col items-center justify-center py-12 gap-2 text-gray-400">
              <Loader2 className="h-8 w-8 animate-spin" />
              <p className="text-sm">Loading your video pool...</p>
            </div>
          ) : filtered?.length === 0 ? (
            <div className="text-center py-12 text-gray-400">
              <Video className="h-12 w-12 mx-auto mb-3 opacity-20" />
              <p className="text-sm">No videos found</p>
            </div>
          ) : (
            <div className="space-y-6">
              {Object.entries(
                (filtered || []).reduce((acc, video) => {
                  const f = video.folder || 'General';
                  if (!acc[f]) acc[f] = [];
                  acc[f].push(video);
                  return acc;
                }, {} as Record<string, Video[]>)
              ).map(([folder, folderVideos]) => (
                <div key={folder} className="space-y-2">
                  <h3 className="text-[10px] font-bold text-gray-400 uppercase tracking-wider ml-1">{folder}</h3>
                  <div className="space-y-1">
                    {folderVideos.map((video) => (
                      <div
                        key={video.id}
                        onClick={() => onSelect(video.id)}
                        className={`flex items-center gap-3 p-3 rounded-xl border transition-all cursor-pointer ${
                          selectedId === video.id
                            ? 'border-primary bg-primary/5 ring-1 ring-primary'
                            : 'border-border hover:border-primary/50 hover:bg-surface-alt'
                        }`}
                      >
                        <div className={`p-2 rounded-lg ${video.status === 'ready' ? 'bg-green-100' : 'bg-blue-100'}`}>
                          <Video className={`h-5 w-5 ${video.status === 'ready' ? 'text-green-600' : 'text-blue-600'}`} />
                        </div>
                        <div className="flex-1 min-w-0">
                          <h3 className="text-sm font-medium text-gray-900 truncate">{video.title || 'Untitled'}</h3>
                          <div className="flex items-center gap-2 mt-0.5">
                            <span className="text-[10px] text-gray-400 font-mono">{video.id}</span>
                            <span className={`text-[10px] px-1.5 py-0.5 rounded-full border ${
                              video.status === 'ready' ? 'bg-green-50 text-green-700 border-green-200' : 'bg-blue-50 text-blue-700 border-blue-200'
                            }`}>
                              {video.status}
                            </span>
                            {video.streaming_mode === 'direct' && (
                              <span className="text-[10px] px-1.5 py-0.5 rounded bg-gray-100 text-gray-600 border border-gray-200">DIRECT</span>
                            )}
                          </div>
                        </div>
                        {selectedId === video.id && (
                          <div className="bg-primary text-white rounded-full p-1">
                            <Check className="h-3 w-3" />
                          </div>
                        )}
                      </div>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        <div className="p-4 border-t bg-gray-50 flex justify-between items-center shrink-0">
          <p className="text-xs text-gray-500">
            {filtered?.length || 0} videos available
          </p>
          <div className="flex gap-2">
            <button
              onClick={() => onSelect(null)}
              className="px-3 py-1.5 text-xs font-medium text-red-600 hover:bg-red-50 rounded-lg"
            >
              Clear Selection
            </button>
            <button
              onClick={onClose}
              className="px-4 py-1.5 bg-primary text-white rounded-lg text-xs font-medium hover:bg-primary-dark"
            >
              Done
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}