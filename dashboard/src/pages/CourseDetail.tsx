import { useState } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { api } from '../lib/api'
import { useAuth } from '../lib/auth'
import { ArrowLeft, Plus, FileText, HelpCircle, Trash2, UserPlus, Image as ImageIcon, X, Video, Search } from 'lucide-react'
import VideoSelector from '../components/VideoSelector'

interface Lesson {
  id: number
  title: string
  description: string
  order: number
  video_id: string | null
  lock_type: string
  is_published: boolean
  quiz_id: number | null
}

interface CourseDetail {
  id: number
  title: string
  description: string
  visibility: string
  tags: unknown
  created_at: string
}

interface EnrollmentFormField {
  label: string
  type: string
  required: boolean
  options?: string[]
}

interface EnrollmentConfig {
  id: string
  course_id: string
  fields: EnrollmentFormField[]
  require_images: boolean
  image_count: number
  image_instructions: string | null
}

export default function CourseDetail() {
  const { id } = useParams()
  const navigate = useNavigate()
  const { isInstructor } = useAuth()
  const queryClient = useQueryClient()
  const [activeTab, setActiveTab] = useState<'lessons' | 'enrollment'>('lessons')
  const [showCreate, setShowCreate] = useState(false)
  const [showSelector, setShowSelector] = useState(false)
  const [createForm, setCreateForm] = useState({ title: '', description: '', order: 1, lock_type: 'none', is_published: true, video_id: null as string | null })
  const [createError, setCreateError] = useState('')

  const { data: course, isLoading: courseLoading } = useQuery<CourseDetail>({
    queryKey: ['course', id],
    queryFn: () => api.get(`/courses/${id}`),
  })

  const { data: lessons, isLoading: lessonsLoading } = useQuery<Lesson[]>({
    queryKey: ['course-lessons', id],
    queryFn: () => api.get(`/courses/${id}/lessons`),
  })

  const { data: enrollmentConfig } = useQuery<EnrollmentConfig>({
    queryKey: ['course-enrollment-config', id],
    queryFn: () => api.get(`/courses/${id}/enrollment-config`),
    enabled: activeTab === 'enrollment',
  })

  const configMutation = useMutation({
    mutationFn: (data: Partial<EnrollmentConfig>) => api.post(`/courses/${id}/enrollment-config`, data),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['course-enrollment-config', id] }),
  })

  const [localConfig, setLocalConfig] = useState<EnrollmentConfig | null>(null)

  // Sync local config when data is loaded
  if (enrollmentConfig && !localConfig) {
    setLocalConfig(enrollmentConfig)
  }

  const handleAddField = () => {
    if (!localConfig) return
    setLocalConfig({
      ...localConfig,
      fields: [...localConfig.fields, { label: 'New Field', type: 'text', required: false }]
    })
  }

  const handleRemoveField = (index: number) => {
    if (!localConfig) return
    const newFields = [...localConfig.fields]
    newFields.splice(index, 1)
    setLocalConfig({ ...localConfig, fields: newFields })
  }

  const handleUpdateField = (index: number, data: Partial<EnrollmentFormField>) => {
    if (!localConfig) return
    const newFields = [...localConfig.fields]
    newFields[index] = { ...newFields[index], ...data }
    setLocalConfig({ ...localConfig, fields: newFields })
  }

  const createMutation = useMutation({
    mutationFn: (data: typeof createForm) => api.post('/lessons', { ...data, course_id: String(id) }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['course-lessons', id] })
      setShowCreate(false)
      setCreateForm({ title: '', description: '', order: 1, lock_type: 'none', is_published: true, video_id: null })
      setCreateError('')
    },
    onError: (err: Error) => setCreateError(err.message),
  })

  const deleteMutation = useMutation({
    mutationFn: (lessonId: number) => api.delete(`/lessons/${lessonId}`),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['course-lessons', id] }),
  })

  const getTags = (tags: unknown): string[] => {
    if (!tags) return []
    if (Array.isArray(tags)) return tags as string[]
    if (typeof tags === 'string') {
      if (tags === '[]' || tags.trim() === '') return []
      try { return JSON.parse(tags) } catch {}
    }
    return []
  }

  return (
    <div className="space-y-6 max-w-4xl">
      <button
        onClick={() => navigate('/courses')}
        className="flex items-center gap-2 text-sm text-gray-500 hover:text-gray-700 transition-colors"
      >
        <ArrowLeft className="h-4 w-4" />
        Back to Courses
      </button>

      {courseLoading ? (
        <div className="h-32 bg-gray-100 rounded-xl animate-pulse" />
      ) : course ? (
        <div className="bg-surface rounded-xl border border-border overflow-hidden">
          <div className="p-6">
            <div className="flex items-start justify-between">
              <div>
                <h1 className="text-2xl font-bold text-gray-900">{course.title}</h1>
                <p className="text-sm text-gray-500 mt-1">{course.description || 'No description'}</p>
              </div>
              <span className={`text-xs px-2 py-1 rounded-full border ${
                course.visibility === 'public' ? 'text-green-600 bg-green-50 border-green-200' :
                course.visibility === 'private' ? 'text-red-600 bg-red-50 border-red-200' :
                'text-gray-600 bg-gray-50 border-gray-200'
              }`}>
                {course.visibility}
              </span>
            </div>
            {getTags(course.tags).length > 0 && (
              <div className="flex gap-2 mt-3">
                {getTags(course.tags).map((tag: string) => (
                  <span key={tag} className="text-xs px-2 py-0.5 rounded-full bg-primary/10 text-primary">
                    {tag}
                  </span>
                ))}
              </div>
            )}
          </div>
          <div className="flex border-t border-border px-4">
            <button
              onClick={() => setActiveTab('lessons')}
              className={`px-4 py-3 text-sm font-medium border-b-2 transition-colors ${
                activeTab === 'lessons' ? 'border-primary text-primary' : 'border-transparent text-gray-500 hover:text-gray-700'
              }`}
            >
              Lessons
            </button>
            <button
              onClick={() => setActiveTab('enrollment')}
              className={`px-4 py-3 text-sm font-medium border-b-2 transition-colors ${
                activeTab === 'enrollment' ? 'border-primary text-primary' : 'border-transparent text-gray-500 hover:text-gray-700'
              }`}
            >
              Enrollment Form
            </button>
          </div>
        </div>
      ) : null}

      {activeTab === 'lessons' ? (
        <>
          <div className="flex items-center justify-between">
            <h2 className="text-lg font-semibold text-gray-900 flex items-center gap-2">
              <FileText className="h-5 w-5" />
              Lessons ({lessons?.length || 0})
            </h2>
            {isInstructor && (
              <button
                onClick={() => setShowCreate(true)}
                className="flex items-center gap-2 px-4 py-2 bg-primary text-white rounded-lg hover:bg-primary-dark transition-colors text-sm font-medium"
              >
                <Plus className="h-4 w-4" />
                Add Lesson
              </button>
            )}
          </div>

          {showCreate && (
            <div className="bg-surface rounded-xl border border-border p-6">
              <h3 className="text-lg font-semibold mb-4">Create Lesson</h3>
              {createError && (
                <div className="mb-4 p-3 rounded-lg bg-red-50 border border-red-200 text-red-600 text-sm">{createError}</div>
              )}
              <form
                onSubmit={(e) => {
                  e.preventDefault()
                  createMutation.mutate(createForm)
                }}
                className="space-y-4"
              >
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Title *</label>
                  <input
                    type="text"
                    value={createForm.title}
                    onChange={(e) => setCreateForm({ ...createForm, title: e.target.value })}
                    className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
                    required
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Description</label>
                  <textarea
                    value={createForm.description}
                    onChange={(e) => setCreateForm({ ...createForm, description: e.target.value })}
                    className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50 min-h-[60px]"
                  />
                </div>
                <div className="grid grid-cols-3 gap-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">Order</label>
                    <input
                      type="number"
                      value={createForm.order}
                      onChange={(e) => setCreateForm({ ...createForm, order: Number(e.target.value) })}
                      className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">Lock Type</label>
                    <select
                      value={createForm.lock_type}
                      onChange={(e) => setCreateForm({ ...createForm, lock_type: e.target.value })}
                      className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
                    >
                      <option value="none">None</option>
                      <option value="previous_lesson">Previous Lesson</option>
                      <option value="quiz">Quiz Required</option>
                    </select>
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">Published</label>
                    <select
                      value={createForm.is_published ? 'true' : 'false'}
                      onChange={(e) => setCreateForm({ ...createForm, is_published: e.target.value === 'true' })}
                      className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
                    >
                      <option value="true">Published</option>
                      <option value="false">Draft</option>
                    </select>
                  </div>
                </div>
                
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Video</label>
                  <div className="flex items-center gap-2">
                    <button
                      type="button"
                      onClick={() => setShowSelector(true)}
                      className="flex-1 flex items-center justify-between gap-2 px-3 py-2 rounded-lg border border-border bg-white text-sm hover:border-primary/50 transition-colors"
                    >
                      <div className="flex items-center gap-2 text-gray-600 truncate">
                        <Video className="h-4 w-4 shrink-0" />
                        <span className="truncate">{createForm.video_id ? `ID: ${createForm.video_id}` : 'Select from Pool'}</span>
                      </div>
                      <Search className="h-4 w-4 text-gray-400 shrink-0" />
                    </button>
                    {createForm.video_id && (
                      <button
                        type="button"
                        onClick={() => setCreateForm({ ...createForm, video_id: null })}
                        className="p-2 text-gray-400 hover:text-red-500 hover:bg-red-50 rounded-lg transition-colors"
                      >
                        <X className="h-4 w-4" />
                      </button>
                    )}
                  </div>
                </div>

                {showSelector && (
                  <VideoSelector
                    selectedId={createForm.video_id}
                    onSelect={(id) => setCreateForm({ ...createForm, video_id: id })}
                    onClose={() => setShowSelector(false)}
                  />
                )}

                <div className="flex gap-3">
                  <button type="submit" className="px-4 py-2 bg-primary text-white rounded-lg hover:bg-primary-dark text-sm font-medium">
                    Create Lesson
                  </button>
                  <button type="button" onClick={() => setShowCreate(false)} className="px-4 py-2 border border-border rounded-lg text-sm text-gray-600 hover:bg-surface-alt">
                    Cancel
                  </button>
                </div>
              </form>
            </div>
          )}

          {lessonsLoading ? (
            <div className="space-y-2">
              {[...Array(3)].map((_, i) => (
                <div key={i} className="h-20 bg-gray-100 rounded-xl animate-pulse" />
              ))}
            </div>
          ) : (
            <div className="space-y-2">
              {lessons?.sort((a, b) => a.order - b.order).map((lesson) => (
                <div
                  key={lesson.id}
                  className="bg-surface rounded-xl border border-border p-4 hover:shadow-sm transition-shadow cursor-pointer"
                  onClick={() => navigate(`/lessons/${lesson.id}`)}
                >
                  <div className="flex items-center gap-4">
                    <div className="flex items-center justify-center w-8 h-8 rounded-lg bg-gray-100 text-sm font-medium text-gray-500 shrink-0">
                      {lesson.order}
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2">
                        <h3 className="font-medium text-gray-900 text-sm">{lesson.title}</h3>
                        {!lesson.is_published && (
                          <span className="text-xs px-1.5 py-0.5 rounded bg-yellow-100 text-yellow-700">Draft</span>
                        )}
                        {lesson.lock_type !== 'none' && (
                          <span className="text-xs px-1.5 py-0.5 rounded bg-orange-100 text-orange-700">{lesson.lock_type}</span>
                        )}
                      </div>
                      <p className="text-xs text-gray-500 mt-0.5 line-clamp-1">{lesson.description || 'No description'}</p>
                    </div>
                    <div className="flex items-center gap-2 shrink-0">
                      {lesson.quiz_id && (
                        <span className="flex items-center gap-1 text-xs text-primary">
                          <HelpCircle className="h-3 w-3" /> Quiz
                        </span>
                      )}
                      {isInstructor && (
                        <button
                          onClick={(e) => {
                            e.stopPropagation()
                            deleteMutation.mutate(lesson.id)
                          }}
                          className="p-1.5 rounded-lg text-gray-400 hover:text-red-500 hover:bg-red-50 transition-colors"
                        >
                          <Trash2 className="h-4 w-4" />
                        </button>
                      )}
                    </div>
                  </div>
                </div>
              ))}
              {lessons?.length === 0 && (
                <div className="p-8 text-center text-sm text-gray-400">No lessons yet. Add your first lesson!</div>
              )}
            </div>
          )}
        </>
      ) : (
        <div className="bg-surface rounded-xl border border-border p-6 space-y-8">
          <div className="flex items-center justify-between">
            <h2 className="text-lg font-semibold flex items-center gap-2">
              <UserPlus className="h-5 w-5 text-primary" />
              Enrollment Form Configuration
            </h2>
            <button
              onClick={() => localConfig && configMutation.mutate(localConfig)}
              className="px-4 py-2 bg-primary text-white rounded-lg hover:bg-primary-dark transition-colors text-sm font-medium"
            >
              Save Configuration
            </button>
          </div>

          <div className="space-y-6">
            <div className="p-4 bg-gray-50 rounded-xl border border-border space-y-4">
              <h3 className="text-sm font-bold flex items-center gap-2">
                <ImageIcon className="h-4 w-4" />
                Proof of Payment / Identity Images
              </h3>
              <div className="flex items-center gap-6">
                <label className="flex items-center gap-2 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={localConfig?.require_images}
                    onChange={(e) => localConfig && setLocalConfig({ ...localConfig, require_images: e.target.checked })}
                    className="rounded text-primary focus:ring-primary"
                  />
                  <span className="text-sm">Require image uploads</span>
                </label>
                {localConfig?.require_images && (
                  <div className="flex items-center gap-2">
                    <span className="text-sm text-gray-500">Count:</span>
                    <input
                      type="number"
                      value={localConfig.image_count}
                      onChange={(e) => setLocalConfig({ ...localConfig, image_count: Number(e.target.value) })}
                      className="w-16 px-2 py-1 rounded border border-border text-sm"
                    />
                  </div>
                )}
              </div>
              {localConfig?.require_images && (
                <div>
                  <label className="block text-xs font-bold text-gray-500 mb-1">Uploader Instructions</label>
                  <input
                    type="text"
                    value={localConfig.image_instructions || ''}
                    onChange={(e) => setLocalConfig({ ...localConfig, image_instructions: e.target.value })}
                    className="w-full px-3 py-2 rounded-lg border border-border text-sm"
                    placeholder="e.g. Please upload your proof of payment receipt"
                  />
                </div>
              )}
            </div>

            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <h3 className="text-sm font-bold">Custom Form Fields</h3>
                <button
                  onClick={handleAddField}
                  className="text-xs text-primary font-medium hover:underline flex items-center gap-1"
                >
                  <Plus className="h-3 w-3" /> Add Field
                </button>
              </div>

              <div className="space-y-3">
                {localConfig?.fields.map((field, idx) => (
                  <div key={idx} className="flex items-start gap-4 p-4 bg-white border border-border rounded-xl shadow-sm">
                    <div className="flex-1 grid grid-cols-12 gap-4">
                      <div className="col-span-5">
                        <label className="block text-[10px] font-bold text-gray-400 mb-1 uppercase">Label</label>
                        <input
                          type="text"
                          value={field.label}
                          onChange={(e) => handleUpdateField(idx, { label: e.target.value })}
                          className="w-full px-3 py-2 rounded-lg border border-border text-sm"
                        />
                      </div>
                      <div className="col-span-3">
                        <label className="block text-[10px] font-bold text-gray-400 mb-1 uppercase">Type</label>
                        <select
                          value={field.type}
                          onChange={(e) => handleUpdateField(idx, { type: e.target.value })}
                          className="w-full px-3 py-2 rounded-lg border border-border text-sm"
                        >
                          <option value="text">Text</option>
                          <option value="number">Number</option>
                          <option value="date">Date</option>
                          <option value="select">Select (Dropdown)</option>
                        </select>
                      </div>
                      <div className="col-span-2 flex items-center mt-6">
                        <label className="flex items-center gap-2 cursor-pointer">
                          <input
                            type="checkbox"
                            checked={field.required}
                            onChange={(e) => handleUpdateField(idx, { required: e.target.checked })}
                            className="rounded text-primary"
                          />
                          <span className="text-xs">Required</span>
                        </label>
                      </div>
                      <div className="col-span-2 flex items-center justify-end mt-6">
                        <button
                          onClick={() => handleRemoveField(idx)}
                          className="p-1.5 rounded-lg text-gray-400 hover:text-red-500 hover:bg-red-50 transition-colors"
                        >
                          <Trash2 className="h-4 w-4" />
                        </button>
                      </div>
                      {field.type === 'select' && (
                        <div className="col-span-12">
                          <label className="block text-[10px] font-bold text-gray-400 mb-1 uppercase">Options (comma separated)</label>
                          <input
                            type="text"
                            value={field.options?.join(', ') || ''}
                            onChange={(e) => handleUpdateField(idx, { options: e.target.value.split(',').map(s => s.trim()) })}
                            className="w-full px-3 py-2 rounded-lg border border-border text-sm"
                          />
                        </div>
                      )}
                    </div>
                  </div>
                ))}
                {localConfig?.fields.length === 0 && (
                  <div className="p-8 text-center border border-dashed border-border rounded-xl text-sm text-gray-400">
                    No custom fields added yet.
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
