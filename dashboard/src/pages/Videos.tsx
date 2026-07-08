import { useState, useRef, useEffect } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { api } from '../lib/api'
import { useAuth } from '../lib/auth'
import { Search, Trash2, RefreshCw, Video as VideoIcon, AlertTriangle, CheckCircle, Upload, X, Loader2, Play, Settings } from 'lucide-react'
import VideoPlayer from '../components/VideoPlayer'

interface Video {
  id: string
  title: string
  description: string | null
  status: string
  duration_seconds: number | null
  width: number | null
  height: number | null
  folder: string
  streaming_mode: string
  watermark_enabled: boolean
  watermark_mode: string
  watermark_segments: number
  watermark_text: string | null
  watermark_color: string
  watermark_font_size: number
  watermark_opacity: number
  watermark_overlay_count: number
  watermark_insert_duration: number
  watermark_insert_repeat: number
  watermark_position: string
  watermark_break_duration: number
  created_at: string
  transcode_method: string
  resolutions?: { resolution: string; status: string; width: number; height: number; bitrate: number }[]
}

interface TranscodeJob {
  id: string
  video_id: string
  status: string
  progress: number
  fail_count: number
  error_message: string | null
  queue_position: number | null
  transcode_method: string
  created_at: string
}

export default function Videos() {
  const { isInstructor } = useAuth()
  const queryClient = useQueryClient()
  const [search, setSearch] = useState('')
  const [showUpload, setShowUpload] = useState(false)
  const [selectedVideoId, setSelectedVideoId] = useState<string | null>(null)
  
  const [uploadFile, setUploadFile] = useState<File | null>(null)
  const [uploadTitle, setUploadTitle] = useState('')
  const [uploadDesc, setUploadDesc] = useState('')
  const [uploadFolder, setUploadFolder] = useState('General')
  const [uploadStreamingMode, setUploadStreamingMode] = useState('hls')
  const [localWatermarkMode, setLocalWatermarkMode] = useState<string | null>(null)
  const [isUploading, setIsUploading] = useState(false)

  const [editForm, setEditForm] = useState({
    title: '',
    description: '',
    folder: 'General',
    streaming_mode: 'hls',
    watermark_enabled: false,
    watermark_mode: 'insert',
    watermark_segments: 10,
    watermark_text: '',
    watermark_color: '#FFFFFF',
    watermark_font_size: 20,
    watermark_opacity: 0.4,
    watermark_overlay_count: 1,
    watermark_insert_duration: 1.0,
    watermark_insert_repeat: 1,
    watermark_break_duration: 60,
  })

  const fileInputRef = useRef<HTMLInputElement>(null)

  const { data: videos, isLoading, isError, error, refetch: refetchVideos } = useQuery<Video[]>({
    queryKey: ['manage-videos'],
    queryFn: () => api.get('/videos/manage'),
    enabled: isInstructor,
  })

  const { data: videoDetail, isLoading: isLoadingDetail } = useQuery<Video>({
    queryKey: ['video-detail', selectedVideoId],
    queryFn: () => api.get(`/videos/manage/${selectedVideoId}`),
    enabled: !!selectedVideoId,
  })

  useEffect(() => {
    if (videoDetail) {
      setEditForm({
        title: videoDetail.title ?? '',
        description: videoDetail.description ?? '',
        folder: videoDetail.folder ?? 'General',
        streaming_mode: videoDetail.streaming_mode ?? 'hls',
        watermark_enabled: videoDetail.watermark_enabled ?? false,
        watermark_mode: videoDetail.watermark_mode ?? 'insert',
        watermark_segments: videoDetail.watermark_segments ?? 10,
        watermark_text: videoDetail.watermark_text ?? '',
        watermark_color: videoDetail.watermark_color ?? '#FFFFFF',
        watermark_font_size: videoDetail.watermark_font_size ?? 20,
        watermark_opacity: videoDetail.watermark_opacity ?? 0.4,
        watermark_overlay_count: videoDetail.watermark_overlay_count ?? 1,
        watermark_insert_duration: videoDetail.watermark_insert_duration ?? 1.0,
        watermark_insert_repeat: videoDetail.watermark_insert_repeat ?? 1,
        watermark_break_duration: videoDetail.watermark_break_duration ?? 60,
      })
      setLocalWatermarkMode(videoDetail.watermark_mode ?? null)
    }
  }, [videoDetail])

  const { data: jobs, refetch: refetchJobs } = useQuery<TranscodeJob[]>({
    queryKey: ['transcode-jobs'],
    queryFn: () => api.get('/videos/jobs'),
    enabled: isInstructor,
    refetchInterval: 5000, // Refresh every 5s to see progress
  })

  const [uploadProgress, setUploadProgress] = useState<number>(0)
  const [uploadError, setUploadError] = useState<string>('')

  const uploadMutation = useMutation({
    mutationFn: async () => {
      if (!uploadFile || !uploadTitle) throw new Error("Missing file or title");
      const CHUNK_SIZE = 500 * 1024 * 1024; // 500MB chunks (local server, no network bottleneck)
      const totalChunks = Math.ceil(uploadFile.size / CHUNK_SIZE);
      const storageKey = `lec_upload_${uploadFile.name}_${uploadFile.size}`;
      let uploadId = localStorage.getItem(storageKey);
      let receivedChunks: number[] = [];

      if (uploadId) {
        try {
          const statusRes = await api.get<{ received_chunks: number[] }>(`/videos/upload/${uploadId}/status`);
          receivedChunks = statusRes.received_chunks;
        } catch {
          uploadId = null;
        }
      }

      if (!uploadId) {
        const initRes = await api.post<{ upload_id: string }>('/videos/upload/init', {
          title: uploadTitle,
          description: uploadDesc,
          filename: uploadFile.name,
          total_size: uploadFile.size,
          total_chunks: totalChunks,
          watermark_enabled: uploadStreamingMode === 'hls',
          folder: uploadFolder,
          streaming_mode: uploadStreamingMode
        });
        uploadId = initRes.upload_id;
        localStorage.setItem(storageKey, uploadId);
      }

      let uploadedCount = receivedChunks.length;
      setUploadProgress(Math.round((uploadedCount / totalChunks) * 100));

      for (let i = 0; i < totalChunks; i++) {
        if (receivedChunks.includes(i)) continue;
        const start = i * CHUNK_SIZE;
        const end = Math.min(start + CHUNK_SIZE, uploadFile.size);
        const chunk = uploadFile.slice(start, end);
        const formData = new FormData();
        formData.append('file', new File([chunk], uploadFile.name));
        await api.post(`/videos/upload/${uploadId}/chunk?chunk_index=${i}`, formData);
        uploadedCount++;
        setUploadProgress(Math.round((uploadedCount / totalChunks) * 100));
      }

      await api.post(`/videos/upload/${uploadId}/complete`);
      localStorage.removeItem(storageKey);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['manage-videos'] })
      setShowUpload(false)
      setUploadFile(null)
      setUploadTitle('')
      setUploadDesc('')
      setIsUploading(false)
      setUploadProgress(0)
      setUploadError('')
    },
    onError: (err: { message?: string }) => {
      setIsUploading(false)
      setUploadError(err.message || 'Upload failed. You can try again to resume.')
    }
  })

  const handleUpload = (e: React.FormEvent) => {
    e.preventDefault()
    if (!uploadFile || !uploadTitle) return
    setIsUploading(true)
    setUploadError('')
    uploadMutation.mutate()
  }

  const updateMutation = useMutation({
    mutationFn: ({ id, data }: { id: string; data: Record<string, unknown> }) =>
      api.put(`/videos/manage/${id}`, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['manage-videos'] })
      queryClient.invalidateQueries({ queryKey: ['video-detail', selectedVideoId] })
      setSelectedVideoId(null)
    },
  })

  const deleteMutation = useMutation({
    mutationFn: (id: string) => api.delete(`/videos/manage/${id}`),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['manage-videos'] })
      setSelectedVideoId(null)
    },
  })

  const transcodeMutation = useMutation({
    mutationFn: ({ id, priority = 0 }: { id: string; priority?: number }) => 
      api.post(`/videos/manage/${id}/transcode?priority=${priority}`),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['manage-videos'] })
      queryClient.invalidateQueries({ queryKey: ['transcode-jobs'] })
    },
  })

  const killMutation = useMutation({
    mutationFn: (jobId: string) => api.post(`/videos/jobs/${jobId}/kill`),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['transcode-jobs'] }),
  })

  const filtered = videos?.filter((v) =>
    v.id.toLowerCase().includes(search.toLowerCase()) ||
    v.title?.toLowerCase().includes(search.toLowerCase())
  )

  const activeJobs = jobs?.filter(j => ['pending', 'running'].includes(j.status)) || []

  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'ready': return 'bg-green-100 text-green-700 border-green-200'
      case 'transcoding': return 'bg-blue-100 text-blue-700 border-blue-200'
      case 'pending': return 'bg-yellow-100 text-yellow-700 border-yellow-200'
      case 'blocked': return 'bg-red-100 text-red-700 border-red-200'
      case 'error': return 'bg-red-100 text-red-700 border-red-200'
      default: return 'bg-gray-100 text-gray-600 border-gray-200'
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Video Management</h1>
          <p className="text-sm text-gray-500 mt-1">Manage video content and transcoding</p>
        </div>
        <div className="flex items-center gap-3">
          <button
            onClick={() => { refetchVideos(); refetchJobs(); }}
            className="flex items-center gap-2 px-3 py-2 border border-border rounded-lg text-sm hover:bg-surface-alt transition-colors"
          >
            <RefreshCw className="h-4 w-4" />
            Refresh
          </button>
          <button
            onClick={() => setShowUpload(true)}
            className="flex items-center gap-2 px-4 py-2 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors"
          >
            <Upload className="h-4 w-4" />
            Upload Video
          </button>
        </div>
      </div>

      {showUpload && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50">
          <div className="bg-white rounded-2xl w-full max-w-md overflow-hidden shadow-2xl">
            <div className="flex items-center justify-between p-4 border-b">
              <h2 className="text-lg font-bold">Upload New Video</h2>
              <button onClick={() => setShowUpload(false)} className="p-1 hover:bg-gray-100 rounded-lg">
                <X className="h-5 w-5 text-gray-400" />
              </button>
            </div>
            <form onSubmit={handleUpload} className="p-6 space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Video File *</label>
                <div 
                  onClick={() => fileInputRef.current?.click()}
                  className="border-2 border-dashed border-gray-200 rounded-xl p-8 text-center cursor-pointer hover:border-primary/50 hover:bg-primary/5 transition-all"
                >
                  <input 
                    type="file" 
                    ref={fileInputRef} 
                    className="hidden" 
                    accept="video/*"
                    onChange={(e) => {
                      const file = e.target.files?.[0]
                      if (file) {
                        setUploadFile(file)
                        if (!uploadTitle) setUploadTitle(file.name.split('.')[0])
                      }
                    }}
                  />
                  {uploadFile ? (
                    <div className="flex items-center justify-center gap-2 text-primary">
                      <VideoIcon className="h-6 w-6" />
                      <span className="text-sm font-medium truncate max-w-[200px]">{uploadFile.name}</span>
                    </div>
                  ) : (
                    <div className="space-y-2">
                      <div className="flex justify-center">
                        <Upload className="h-8 w-8 text-gray-400" />
                      </div>
                      <p className="text-sm text-gray-500">Click to select or drag and drop</p>
                      <p className="text-xs text-gray-400">MP4, MKV, MOV (Max 500MB)</p>
                    </div>
                  )}
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Title *</label>
                <input
                  type="text"
                  value={uploadTitle}
                  onChange={(e) => setUploadTitle(e.target.value)}
                  className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
                  placeholder="Enter video title"
                  required
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Description</label>
                <textarea
                  value={uploadDesc}
                  onChange={(e) => setUploadDesc(e.target.value)}
                  className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50 min-h-[80px]"
                  placeholder="Optional description"
                />
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Folder</label>
                  <input
                    type="text"
                    value={uploadFolder}
                    onChange={(e) => setUploadFolder(e.target.value)}
                    className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
                    placeholder="General"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Mode</label>
                  <select
                    value={uploadStreamingMode}
                    onChange={(e) => setUploadStreamingMode(e.target.value)}
                    className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50 bg-white"
                  >
                    <option value="hls">HLS (Dynamic Watermark)</option>
                    <option value="direct">Direct (No Watermark)</option>
                  </select>
                </div>
              </div>
              <div className="pt-4 flex gap-3">
                <button
                  type="button"
                  onClick={() => setShowUpload(false)}
                  className="flex-1 px-4 py-2 border border-border rounded-lg text-sm font-medium text-gray-600 hover:bg-gray-50"
                  disabled={isUploading}
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={!uploadFile || !uploadTitle || isUploading}
                  className="flex-1 px-4 py-2 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark disabled:opacity-50 flex items-center justify-center gap-2"
                >
                  {isUploading ? (
                    <>
                      <Loader2 className="h-4 w-4 animate-spin" />
                      {uploadProgress}% Uploading...
                    </>
                  ) : (
                    'Start Upload'
                  )}
                </button>
              </div>
              
              {isUploading && (
                <div className="w-full bg-gray-200 rounded-full h-2 mt-2">
                  <div 
                    className="bg-primary h-2 rounded-full transition-all duration-300" 
                    style={{ width: `${uploadProgress}%` }}
                  ></div>
                </div>
              )}
              
              {uploadError && (
                <div className="mt-2 p-3 bg-red-50 text-red-700 text-sm rounded-lg border border-red-200">
                  {uploadError}
                </div>
              )}
            </form>
          </div>
        </div>
      )}


      {selectedVideoId && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 overflow-y-auto">
          <div className="bg-white rounded-2xl w-full max-w-4xl overflow-hidden shadow-2xl my-8">
            <div className="flex items-center justify-between p-4 border-b bg-surface">
              <div>
                <h2 className="text-lg font-bold">Edit Video Properties</h2>
                <p className="text-xs text-gray-500">ID: {selectedVideoId}</p>
              </div>
              <button onClick={() => { setSelectedVideoId(null); setLocalWatermarkMode(null); }} className="p-1 hover:bg-gray-100 rounded-lg">
                <X className="h-5 w-5 text-gray-400" />
              </button>
            </div>
            
            {isLoadingDetail || !videoDetail ? (
              <div className="h-[60vh] flex flex-col items-center justify-center gap-4">
                <Loader2 className="h-12 w-12 animate-spin text-primary" />
                <p className="text-gray-500 font-medium">Loading video details...</p>
              </div>
            ) : (
              <div className="flex flex-col md:flex-row h-full max-h-[80vh] overflow-hidden">
                <div className="flex-1 p-6 overflow-y-auto border-r">
                  <div className="space-y-6">
                    {videoDetail.status === 'ready' ? (
                      <div>
                        <h3 className="text-sm font-semibold mb-3 flex items-center gap-2">
                          <Play className="h-4 w-4" />
                          Preview
                        </h3>
                        {videoDetail.resolutions?.some(r => r.status === 'ready') ? (
                          <>
                            <VideoPlayer 
                              manifestUrl={`${api.baseUrl}/videos/manage/${videoDetail.id}/playlist/${videoDetail.resolutions.find(r => r.status === 'ready')?.resolution}`} 
                            />
                            <p className="text-[10px] text-gray-400 mt-2 text-center italic">
                              Previewing at {videoDetail.resolutions.find(r => r.status === 'ready')?.resolution} resolution. Custom watermark applied for your session.
                            </p>
                          </>
                        ) : (
                          <div className="bg-gray-100 rounded-xl aspect-video flex flex-col items-center justify-center text-gray-400 gap-2 border-2 border-dashed">
                            <p className="text-sm font-medium">No ready resolutions for playback</p>
                          </div>
                        )}
                      </div>
                    ) : (
                      <div className="bg-gray-100 rounded-xl aspect-video flex flex-col items-center justify-center text-gray-400 gap-2 border-2 border-dashed">
                        <VideoIcon className="h-12 w-12 opacity-20" />
                        <p className="text-sm font-medium">Video not ready for playback</p>
                        <span className="text-xs uppercase bg-gray-200 px-2 py-1 rounded">{videoDetail.status}</span>
                      </div>
                    )}

                    <div className="grid grid-cols-2 gap-4">
                      <div className="p-3 rounded-xl border bg-gray-50/50">
                        <p className="text-[10px] text-gray-500 uppercase font-bold mb-1">Duration</p>
                        <p className="text-sm font-medium">
                          {videoDetail.duration_seconds ? `${Math.floor(videoDetail.duration_seconds / 60)}m ${Math.floor(videoDetail.duration_seconds % 60)}s` : 'N/A'}
                        </p>
                      </div>
                      <div className="p-3 rounded-xl border bg-gray-50/50">
                        <p className="text-[10px] text-gray-500 uppercase font-bold mb-1">Dimensions</p>
                        <p className="text-sm font-medium">
                          {videoDetail.width && videoDetail.height ? `${videoDetail.width}x${videoDetail.height}` : 'N/A'}
                        </p>
                      </div>
                    </div>

                    <div>
                      <h3 className="text-sm font-semibold mb-3">Available Qualities</h3>
                      <div className="space-y-2">
                        {videoDetail.resolutions?.map(res => (
                          <div key={res.resolution} className="flex items-center justify-between p-2 rounded-lg border bg-surface text-sm">
                            <span className="font-medium">{res.resolution}</span>
                            <div className="flex items-center gap-4 text-xs text-gray-500">
                              <span>{res.width}x{res.height}</span>
                              <span>{(res.bitrate / 1000000).toFixed(1)} Mbps</span>
                              <span className={`px-1.5 py-0.5 rounded ${getStatusBadge(res.status)}`}>{res.status}</span>
                            </div>
                          </div>
                        ))}
                        {(!videoDetail.resolutions || videoDetail.resolutions.length === 0) && (
                          <p className="text-xs text-gray-400 italic">No resolutions available yet</p>
                        )}
                      </div>
                    </div>
                  </div>
                </div>

                <div className="w-full md:w-80 p-6 bg-surface overflow-y-auto">
                  <form 
                    onSubmit={(e) => {
                      e.preventDefault();
                      const payload: Record<string, unknown> = {
                        title: editForm.title,
                        description: editForm.description,
                        folder: editForm.folder,
                        streaming_mode: editForm.streaming_mode,
                        watermark_enabled: editForm.watermark_enabled,
                        watermark_mode: editForm.watermark_mode,
                        watermark_segments: editForm.watermark_segments,
                        watermark_text: editForm.watermark_text || null,
                        watermark_color: editForm.watermark_color,
                        watermark_font_size: editForm.watermark_font_size,
                        watermark_opacity: editForm.watermark_opacity,
                        watermark_overlay_count: editForm.watermark_overlay_count,
                        watermark_insert_duration: editForm.watermark_insert_duration,
                        watermark_insert_repeat: editForm.watermark_insert_repeat,
                        watermark_break_duration: editForm.watermark_break_duration,
                      };
                      updateMutation.mutate({ id: videoDetail.id, data: payload });
                    }}
                    className="space-y-4"
                  >
                    <div className="grid grid-cols-2 gap-3">
                      <div>
                        <label className="block text-[10px] font-bold text-gray-500 uppercase mb-1">Title</label>
                        <input value={editForm.title} onChange={(e) => setEditForm(f => ({ ...f, title: e.target.value }))} className="w-full px-3 py-2 border rounded-lg text-sm" />
                      </div>
                      <div>
                        <label className="block text-[10px] font-bold text-gray-500 uppercase mb-1">Folder</label>
                        <input value={editForm.folder} onChange={(e) => setEditForm(f => ({ ...f, folder: e.target.value }))} className="w-full px-3 py-2 border rounded-lg text-sm" />
                      </div>
                    </div>
                    <div>
                      <label className="block text-[10px] font-bold text-gray-500 uppercase mb-1">Streaming Mode</label>
                      <select value={editForm.streaming_mode} onChange={(e) => setEditForm(f => ({ ...f, streaming_mode: e.target.value }))} className="w-full px-3 py-2 border rounded-lg text-sm bg-white">
                        <option value="hls">HLS (Adaptive + Watermark)</option>
                        <option value="direct">Direct (Single File, No Watermark)</option>
                      </select>
                    </div>
                    <div>
                      <label className="block text-[10px] font-bold text-gray-500 uppercase mb-1">Description</label>
                      <textarea value={editForm.description} onChange={(e) => setEditForm(f => ({ ...f, description: e.target.value }))} className="w-full px-3 py-2 border rounded-lg text-sm min-h-[60px]" />
                    </div>

                    <div className="pt-4 border-t">
                      <div className="flex items-center justify-between mb-4">
                        <h3 className="text-xs font-bold uppercase text-primary">Watermarking</h3>
                        <label className="relative inline-flex items-center cursor-pointer">
                          <input type="checkbox" checked={editForm.watermark_enabled} onChange={(e) => setEditForm(f => ({ ...f, watermark_enabled: e.target.checked }))} className="sr-only peer" />
                          <div className="w-9 h-5 bg-gray-200 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:bg-primary"></div>
                        </label>
                      </div>

                      <div className="space-y-4">
                        <div>
                          <label className="block text-[10px] font-bold text-gray-500 uppercase mb-1">Mode</label>
                          <select 
                            value={editForm.watermark_mode}
                            onChange={(e) => setEditForm(f => ({ ...f, watermark_mode: e.target.value }))}
                            className="w-full px-3 py-2 border rounded-lg text-sm bg-white"
                          >
                            <option value="insert">Insert (Replace Segments)</option>
                            <option value="overlay">Overlay (Draw Text)</option>
                          </select>
                        </div>
                        
                        <div>
                          <label className="block text-[10px] font-bold text-gray-500 uppercase mb-1">Segments Count</label>
                          <input type="number" value={editForm.watermark_segments} onChange={(e) => setEditForm(f => ({ ...f, watermark_segments: parseInt(e.target.value) || 0 }))} className="w-full px-3 py-2 border rounded-lg text-sm" />
                          <p className="text-[10px] text-gray-400 mt-1">Number of times watermark appears per video</p>
                        </div>

                        <div>
                          <label className="block text-[10px] font-bold text-gray-500 uppercase mb-1">Custom Text</label>
                          <input value={editForm.watermark_text} onChange={(e) => setEditForm(f => ({ ...f, watermark_text: e.target.value }))} className="w-full px-3 py-2 border rounded-lg text-sm" placeholder="Leave empty for user email" />
                        </div>

                        <div className="grid grid-cols-2 gap-3">
                          <div>
                            <label className="block text-[10px] font-bold text-gray-500 uppercase mb-1">Color</label>
                            <input type="color" value={editForm.watermark_color} onChange={(e) => setEditForm(f => ({ ...f, watermark_color: e.target.value }))} className="w-full h-9 p-1 border rounded-lg bg-white" />
                          </div>
                          <div>
                            <label className="block text-[10px] font-bold text-gray-500 uppercase mb-1">Font Size</label>
                            <input type="number" value={editForm.watermark_font_size} onChange={(e) => setEditForm(f => ({ ...f, watermark_font_size: parseInt(e.target.value) || 0 }))} className="w-full px-3 py-2 border rounded-lg text-sm" />
                          </div>
                        </div>

                        <div>
                          <label className="block text-[10px] font-bold text-gray-500 uppercase mb-1">Opacity</label>
                          <input type="range" min="0" max="1" step="0.1" value={editForm.watermark_opacity} onChange={(e) => setEditForm(f => ({ ...f, watermark_opacity: parseFloat(e.target.value) }))} className="w-full accent-primary" />
                        </div>

                        {editForm.watermark_mode === 'overlay' ? (
                          <div>
                            <label className="block text-[10px] font-bold text-gray-500 uppercase mb-1">Overlay Count</label>
                            <input type="number" value={editForm.watermark_overlay_count} onChange={(e) => setEditForm(f => ({ ...f, watermark_overlay_count: parseInt(e.target.value) || 0 }))} className="w-full px-3 py-2 border rounded-lg text-sm" />
                          </div>
                        ) : (
                          <div className="grid grid-cols-3 gap-3">
                            <div>
                              <label className="block text-[10px] font-bold text-gray-500 uppercase mb-1">Duration (s)</label>
                              <input type="number" step="0.1" value={editForm.watermark_insert_duration} onChange={(e) => setEditForm(f => ({ ...f, watermark_insert_duration: parseFloat(e.target.value) || 0 }))} className="w-full px-3 py-2 border rounded-lg text-sm" />
                            </div>
                            <div>
                              <label className="block text-[10px] font-bold text-gray-500 uppercase mb-1">Repeat</label>
                              <input type="number" value={editForm.watermark_insert_repeat} onChange={(e) => setEditForm(f => ({ ...f, watermark_insert_repeat: parseInt(e.target.value) || 0 }))} className="w-full px-3 py-2 border rounded-lg text-sm" />
                            </div>
                            <div>
                              <label className="block text-[10px] font-bold text-gray-500 uppercase mb-1">Break (s)</label>
                              <input type="number" value={editForm.watermark_break_duration} onChange={(e) => setEditForm(f => ({ ...f, watermark_break_duration: parseInt(e.target.value) || 0 }))} className="w-full px-3 py-2 border rounded-lg text-sm" />
                              <p className="text-[10px] text-gray-400 mt-1">Break screen countdown duration</p>
                            </div>
                          </div>
                        )}
                      </div>
                    </div>

                    <div className="pt-6">
                      <button
                        type="submit"
                        disabled={updateMutation.isPending}
                        className="w-full px-4 py-2 bg-primary text-white rounded-lg text-sm font-bold hover:bg-primary-dark disabled:opacity-50 flex items-center justify-center gap-2"
                      >
                        {updateMutation.isPending ? <Loader2 className="h-4 w-4 animate-spin" /> : 'Save Changes'}
                      </button>
                    </div>
                  </form>
                </div>
              </div>
            )}
          </div>
        </div>
      )}

      {activeJobs.length > 0 && (
        <div className="bg-blue-50 border border-blue-100 rounded-xl p-4 space-y-3">
          <h2 className="text-sm font-semibold text-blue-900 flex items-center gap-2">
            <RefreshCw className="h-4 w-4 animate-spin" />
            Active Transcode Queue ({activeJobs.length})
          </h2>
          <div className="space-y-2">
            {activeJobs.map(job => (
              <div key={job.id} className="bg-white rounded-lg p-3 border border-blue-200 flex items-center justify-between shadow-sm">
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2">
                    <span className="text-xs font-medium text-gray-900 truncate">Job {job.id.slice(0,8)}</span>
                    <span className="text-[10px] px-1.5 py-0.5 rounded bg-blue-100 text-blue-700 uppercase">
                      {job.status} {job.queue_position !== null ? `(Pos: ${job.queue_position})` : ''}
                    </span>
                    {job.transcode_method === 'mux' ? (
                      <span className="text-[10px] px-1.5 py-0.5 rounded bg-purple-100 text-purple-700 border border-purple-200 font-medium">MUX</span>
                    ) : (
                      <span className="text-[10px] px-1.5 py-0.5 rounded bg-orange-100 text-orange-700 border border-orange-200 font-medium">FFMPEG</span>
                    )}
                    {job.fail_count > 0 && (
                      <span className="text-[10px] px-1.5 py-0.5 rounded bg-red-100 text-red-700">
                        Fails: {job.fail_count}
                      </span>
                    )}
                  </div>
                  <div className="mt-1.5 w-full bg-gray-100 rounded-full h-1.5">
                    <div 
                      className="bg-blue-600 h-1.5 rounded-full transition-all duration-500" 
                      style={{ width: `${job.progress}%` }}
                    />
                  </div>
                </div>
                <button
                  onClick={() => killMutation.mutate(job.id)}
                  className="ml-4 p-1.5 rounded-lg text-gray-400 hover:text-red-600 hover:bg-red-50 transition-colors"
                  title="Kill Job"
                >
                  <Trash2 className="h-4 w-4" />
                </button>
              </div>
            ))}
          </div>
        </div>
      )}

      <div className="relative max-w-sm">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
        <input
          type="text"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="w-full pl-10 pr-4 py-2 rounded-lg border border-border bg-surface text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
          placeholder="Search videos by ID or title..."
        />
      </div>

      {isError ? (
        <div className="p-8 text-center">
          <div className="inline-flex items-center justify-center w-12 h-12 rounded-full bg-red-100 mb-4">
            <AlertTriangle className="h-6 w-6 text-red-600" />
          </div>
          <h3 className="text-sm font-semibold text-gray-900 mb-1">Failed to load videos</h3>
          <p className="text-sm text-gray-500 mb-4">{(error as Error)?.message || 'An unexpected error occurred'}</p>
          <button
            onClick={() => refetchVideos()}
            className="inline-flex items-center gap-2 px-4 py-2 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors"
          >
            <RefreshCw className="h-4 w-4" />
            Retry
          </button>
        </div>
      ) : isLoading ? (
        <div className="space-y-2">
          {[...Array(3)].map((_, i) => <div key={i} className="h-20 bg-gray-100 rounded-xl animate-pulse" />)}
        </div>
      ) : !videos || videos.length === 0 ? (
        <div className="p-8 text-center text-sm text-gray-400">No videos found</div>
      ) : (
        <div className="space-y-8">
          {Object.entries(
            (filtered || []).reduce((acc, video) => {
              const f = video.folder || 'General';
              if (!acc[f]) acc[f] = [];
              acc[f].push(video);
              return acc;
            }, {} as Record<string, Video[]>)
          ).map(([folder, folderVideos]) => (
            <div key={folder} className="space-y-3">
              <h2 className="text-sm font-bold text-gray-500 uppercase tracking-wider flex items-center gap-2">
                <span className="w-2 h-2 rounded-full bg-primary" />
                {folder} ({folderVideos.length})
              </h2>
              <div className="space-y-2">
                {folderVideos.map((video) => (
                  <div 
                    key={video.id} 
                    onClick={() => setSelectedVideoId(video.id)}
                    className="bg-surface rounded-xl border border-border p-4 hover:border-primary/50 transition-all cursor-pointer group"
                  >
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-3 flex-1 min-w-0">
                        <div className={`p-2 rounded-lg ${video.status === 'blocked' ? 'bg-red-100' : 'bg-blue-100'} group-hover:scale-110 transition-transform`}>
                          <VideoIcon className={`h-5 w-5 ${video.status === 'blocked' ? 'text-red-600' : 'text-blue-600'}`} />
                        </div>
                        <div className="min-w-0 flex-1">
                          <div className="flex items-center gap-2">
                            <h3 className="text-sm font-medium text-gray-900 truncate group-hover:text-primary transition-colors">{video.title || 'Untitled'}</h3>
                            <span className={`text-xs px-2 py-0.5 rounded-full border ${getStatusBadge(video.status)}`}>
                              {video.status}
                            </span>
                            {video.streaming_mode === 'direct' && (
                              <span className="text-[10px] px-1.5 py-0.5 rounded bg-gray-100 text-gray-600 border border-gray-200">DIRECT</span>
                            )}
                            {video.transcode_method === 'mux' && (
                              <span className="text-[10px] px-1.5 py-0.5 rounded bg-blue-100 text-blue-700 border border-blue-200">MUX</span>
                            )}
                          </div>
                          <p className="text-xs text-gray-500">ID: {video.id}</p>
                          {video.duration_seconds && (
                            <p className="text-xs text-gray-400">
                              {Math.floor(video.duration_seconds / 60)}:{(video.duration_seconds % 60).toString().padStart(2, '0')}
                              {video.width && video.height && ` • ${video.width}x${video.height}`}
                            </p>
                          )}
                        </div>
                      </div>
                      <div className="flex items-center gap-2 shrink-0" onClick={(e) => e.stopPropagation()}>
                        <button
                          onClick={() => setSelectedVideoId(video.id)}
                          className="p-1.5 rounded-lg text-gray-400 hover:text-primary hover:bg-primary/5 transition-colors"
                          title="Edit & Preview"
                        >
                          <Settings className="h-4 w-4" />
                        </button>
                        
                        {video.status !== 'transcoding' && video.status !== 'blocked' && (
                          <button
                            onClick={() => transcodeMutation.mutate({ id: video.id })}
                            className="p-1.5 rounded-lg text-gray-400 hover:text-blue-600 hover:bg-blue-50 transition-colors"
                            title="Re-transcode"
                          >
                            <RefreshCw className="h-4 w-4" />
                          </button>
                        )}
                        {video.status === 'blocked' ? (
                          <button
                            onClick={() => updateMutation.mutate({ id: video.id, data: { status: 'ready' } })}
                            className="p-1.5 rounded-lg text-green-600 hover:bg-green-50 transition-colors"
                            title="Unblock"
                          >
                            <CheckCircle className="h-4 w-4" />
                          </button>
                        ) : (
                          <button
                            onClick={() => updateMutation.mutate({ id: video.id, data: { status: 'blocked' } })}
                            className="p-1.5 rounded-lg text-yellow-600 hover:bg-yellow-50 transition-colors"
                            title="Block video"
                          >
                            <AlertTriangle className="h-4 w-4" />
                          </button>
                        )}
                        <button
                          onClick={() => {
                            if (confirm('Are you sure you want to delete this video?')) {
                              deleteMutation.mutate(video.id)
                            }
                          }}
                          className="p-1.5 rounded-lg text-gray-400 hover:text-red-500 hover:bg-red-50 transition-colors"
                          title="Delete"
                        >
                          <Trash2 className="h-4 w-4" />
                        </button>
                      </div>
                    </div>
                    {video.resolutions && video.resolutions.length > 0 && video.streaming_mode === 'hls' && (
                      <div className="mt-3 pt-3 border-t border-border">
                        <p className="text-xs text-gray-500 mb-2 font-medium">Available Resolutions:</p>
                        <div className="flex flex-wrap gap-2">
                          {video.resolutions.map((r) => (
                            <span
                              key={r.resolution}
                              className={`text-[10px] px-2 py-0.5 rounded-full border flex items-center gap-1.5 ${
                                r.status === 'ready' ? 'bg-green-50 text-green-700 border-green-200' :
                                r.status === 'transcoding' ? 'bg-blue-50 text-blue-700 border-blue-200' :
                                'bg-gray-50 text-gray-600 border-gray-200'
                              }`}
                            >
                              <span className={`w-1 h-1 rounded-full ${r.status === 'ready' ? 'bg-green-500' : 'bg-blue-500'}`} />
                              {r.resolution}
                            </span>
                          ))}
                        </div>
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
  )
}
