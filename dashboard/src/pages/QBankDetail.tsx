import { useState } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { api } from '../lib/api'
import { useAuth } from '../lib/auth'
import { ChevronLeft, Plus, Trash2, Edit2, CheckCircle, XCircle } from 'lucide-react'

interface Question {
  id: string
  qbank_id: string
  type: string
  question: string
  options: string[] | null
  correct_answer: string
  explanation: string | null
  points: number
  tags: string[]
  order: number
}

interface Enrollment {
  id: string
  user_id: string
  qbank_id: string
  status: string
  form_data_json: string
  created_at: string
}

export default function QBankDetail() {
  const { id } = useParams()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const { isInstructor } = useAuth()
  const [activeTab, setActiveTab] = useState<'questions' | 'enrollments'>('questions')
  const [showAddQuestion, setShowAddQuestion] = useState(false)
  const [qForm, setQForm] = useState({ 
    question: '', 
    options: '', 
    correct_answer: '', 
    explanation: '', 
    tags: '', 
    points: 1 
  })

  const { data: qbank } = useQuery({
    queryKey: ['qbanks', id],
    queryFn: () => api.get(`/qbanks/${id}`),
  })

  const { data: questions } = useQuery<Question[]>({
    queryKey: ['qbanks', id, 'questions'],
    queryFn: () => api.get(`/qbanks/${id}/questions`),
  })

  const { data: enrollments } = useQuery<Enrollment[]>({
    queryKey: ['qbanks', id, 'enrollments'],
    queryFn: () => api.get('/qbanks/enrollments/all').then(res => res.filter((e: Enrollment) => e.qbank_id === id)),
  })

  const addQMutation = useMutation({
    mutationFn: (data: typeof qForm) => api.post(`/qbanks/${id}/questions`, {
      ...data,
      options: data.options.split('\n').map(o => o.trim()).filter(o => o.length > 0),
      tags: data.tags.split(',').map(t => t.trim()).filter(t => t.length > 0),
    }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['qbanks', id, 'questions'] })
      setShowAddQuestion(false)
      setQForm({ question: '', options: '', correct_answer: '', explanation: '', tags: '', points: 1 })
    }
  })

  const deleteQMutation = useMutation({
    mutationFn: (qId: string) => api.delete(`/qbanks/questions/${qId}`),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['qbanks', id, 'questions'] }),
  })

  const approveMutation = useMutation({
    mutationFn: (eId: string) => api.post(`/qbanks/enrollments/${eId}/approve`),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['qbanks', id, 'enrollments'] }),
  })

  const rejectMutation = useMutation({
    mutationFn: (eId: string) => api.post(`/qbanks/enrollments/${eId}/reject`),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['qbanks', id, 'enrollments'] }),
  })

  if (!qbank) return null

  return (
    <div className="space-y-6">
      <button onClick={() => navigate('/qbanks')} className="flex items-center text-sm text-gray-500 hover:text-gray-900 transition-colors">
        <ChevronLeft className="h-4 w-4 mr-1" /> Back to QBanks
      </button>

      <div className="bg-surface rounded-xl border border-border p-6">
        <div className="flex justify-between items-start">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">{qbank.title}</h1>
            <p className="text-gray-500 mt-1 max-w-2xl">{qbank.description}</p>
          </div>
          <div className="flex gap-2">
            <button className="p-2 border border-border rounded-lg hover:bg-surface-alt transition-colors">
              <Edit2 className="h-4 w-4 text-gray-600" />
            </button>
            <button className="p-2 border border-border rounded-lg hover:bg-red-50 hover:border-red-100 transition-colors group">
              <Trash2 className="h-4 w-4 text-gray-400 group-hover:text-red-500" />
            </button>
          </div>
        </div>

        <div className="flex border-b border-border mt-8">
          <button
            onClick={() => setActiveTab('questions')}
            className={`px-6 py-3 text-sm font-medium border-b-2 transition-colors ${
              activeTab === 'questions' ? 'border-primary text-primary' : 'border-transparent text-gray-500 hover:text-gray-700'
            }`}
          >
            Questions ({questions?.length ?? 0})
          </button>
          <button
            onClick={() => setActiveTab('enrollments')}
            className={`px-6 py-3 text-sm font-medium border-b-2 transition-colors ${
              activeTab === 'enrollments' ? 'border-primary text-primary' : 'border-transparent text-gray-500 hover:text-gray-700'
            }`}
          >
            Enrollments ({enrollments?.length ?? 0})
          </button>
        </div>
      </div>

      {activeTab === 'questions' && (
        <div className="space-y-4">
          <div className="flex justify-between items-center">
            <h2 className="text-lg font-semibold text-gray-900">Manage Questions</h2>
            <button
              onClick={() => setShowAddQuestion(true)}
              className="flex items-center gap-2 px-4 py-2 bg-primary text-white rounded-lg hover:bg-primary-dark transition-colors text-sm font-medium"
            >
              <Plus className="h-4 w-4" /> Add Question
            </button>
          </div>

          {showAddQuestion && (
            <div className="bg-surface rounded-xl border border-border p-6 shadow-sm">
              <h3 className="font-semibold mb-4">New Question</h3>
              <form onSubmit={(e) => { e.preventDefault(); addQMutation.mutate(qForm); }} className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Question Text</label>
                  <textarea
                    value={qForm.question}
                    onChange={(e) => setQForm({ ...qForm, question: e.target.value })}
                    className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:ring-2 focus:ring-primary/50"
                    required
                  />
                </div>
                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">Options (one per line)</label>
                    <textarea
                      value={qForm.options}
                      onChange={(e) => setQForm({ ...qForm, options: e.target.value })}
                      className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:ring-2 focus:ring-primary/50"
                      placeholder="Option A&#10;Option B&#10;Option C"
                      required
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">Correct Answer (exact match)</label>
                    <input
                      type="text"
                      value={qForm.correct_answer}
                      onChange={(e) => setQForm({ ...qForm, correct_answer: e.target.value })}
                      className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:ring-2 focus:ring-primary/50"
                      required
                    />
                  </div>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Explanation</label>
                  <textarea
                    value={qForm.explanation}
                    onChange={(e) => setQForm({ ...qForm, explanation: e.target.value })}
                    className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:ring-2 focus:ring-primary/50"
                  />
                </div>
                <div className="flex gap-3">
                  <button type="submit" className="px-4 py-2 bg-primary text-white rounded-lg text-sm font-medium">Save Question</button>
                  <button type="button" onClick={() => setShowAddQuestion(false)} className="px-4 py-2 border border-border rounded-lg text-sm">Cancel</button>
                </div>
              </form>
            </div>
          )}

          <div className="space-y-3">
            {questions?.map((q, i) => (
              <div key={q.id} className="bg-surface rounded-xl border border-border p-4 flex gap-4">
                <div className="h-8 w-8 rounded-full bg-gray-100 flex items-center justify-center shrink-0 text-sm font-bold text-gray-500">{i + 1}</div>
                <div className="flex-1">
                  <p className="text-gray-900 font-medium">{q.question}</p>
                  <div className="grid grid-cols-2 gap-x-8 gap-y-1 mt-3">
                    {q.options?.map((opt) => (
                      <div key={opt} className={`text-xs px-2 py-1 rounded ${opt === q.correct_answer ? 'bg-green-50 text-green-700 font-semibold' : 'text-gray-500'}`}>
                        {opt}
                      </div>
                    ))}
                  </div>
                </div>
                <button 
                  onClick={() => {
                    if (confirm('Delete this question?')) {
                      deleteQMutation.mutate(q.id)
                    }
                  }}
                  className="p-2 text-gray-400 hover:text-red-500 transition-colors self-start"
                >
                  <Trash2 className="h-4 w-4" />
                </button>
              </div>
            ))}
          </div>
        </div>
      )}

      {activeTab === 'enrollments' && (
        <div className="bg-surface rounded-xl border border-border overflow-hidden">
          <table className="w-full">
            <thead className="bg-surface-alt border-b border-border">
              <tr>
                <th className="text-left px-6 py-3 text-xs font-medium text-gray-500 uppercase">Student</th>
                <th className="text-left px-6 py-3 text-xs font-medium text-gray-500 uppercase">Status</th>
                <th className="text-left px-6 py-3 text-xs font-medium text-gray-500 uppercase">Joined</th>
                <th className="text-right px-6 py-3 text-xs font-medium text-gray-500 uppercase">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {enrollments?.map((e) => (
                <tr key={e.id}>
                  <td className="px-6 py-4 text-sm text-gray-900">{e.user_id}</td>
                  <td className="px-6 py-4">
                    <span className={`text-xs px-2 py-0.5 rounded-full border ${
                      e.status === 'approved' ? 'text-green-600 bg-green-50 border-green-200' :
                      e.status === 'pending' ? 'text-amber-600 bg-amber-50 border-amber-200' :
                      'text-red-600 bg-red-50 border-red-200'
                    }`}>
                      {e.status}
                    </span>
                  </td>
                  <td className="px-6 py-4 text-sm text-gray-500">{new Date(e.created_at).toLocaleDateString()}</td>
                  <td className="px-6 py-4 text-right">
                    {e.status === 'pending' && (
                      <div className="flex justify-end gap-2">
                        <button onClick={() => approveMutation.mutate(e.id)} className="p-1 text-green-600 hover:bg-green-50 rounded transition-colors"><CheckCircle className="h-4 w-4" /></button>
                        <button onClick={() => rejectMutation.mutate(e.id)} className="p-1 text-red-600 hover:bg-red-50 rounded transition-colors"><XCircle className="h-4 w-4" /></button>
                      </div>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
