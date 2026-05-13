// 与服务器通信的统一入口
async function api(method, path, body) {
  const opts = { method, headers: {}, credentials: 'include' }
  if (body) {
    opts.headers['Content-Type'] = 'application/json'
    opts.body = JSON.stringify(body)
  }
  const res  = await fetch('/api' + path, opts)
  const data = await res.json()
  if (!res.ok) throw new Error(data.error || '请求失败')
  return data
}

const API = {
  // 认证
  me:       ()           => api('GET',  '/auth/me'),
  register: (u,e,p)      => api('POST', '/auth/register', { username:u, email:e, password:p }),
  login:    (e,p)        => api('POST', '/auth/login',    { email:e, password:p }),
  logout:   ()           => api('POST', '/auth/logout'),

  // 谱子
  getSongs: (params={})  => api('GET',  '/songs?' + new URLSearchParams(params)),
  getSong:  (id)         => api('GET',  `/songs/${id}`),
  publish:  (data)       => api('POST', '/songs', data),
  like:     (sid,vid)    => api('POST', `/songs/${sid}/versions/${vid}/like`),
  favorite: (id)         => api('POST', `/songs/${id}/favorite`),
  comment:  (id,content) => api('POST', `/songs/${id}/comments`, { content }),
  downloadUrl:  (sid,vid) => `/api/songs/${sid}/versions/${vid}/download`,
  previewUrl:   (sid,vid) => api('GET', `/songs/${sid}/versions/${vid}/preview-url`),

  // 用户
  getUser:  (username)   => api('GET',  `/users/${username}`),
}
