// Separate client leases: an unfocused window must not clear another window.
export function createForeground({ now = Date.now, ttl = 5000, maxClients = 128 } = {}) {
  const clients = new Map(), legacy = Symbol('legacy client')
  const fresh = value => value.visible && now() - value.updatedAt < ttl
  return {
    update(payload) {
      if (typeof payload?.visible !== 'boolean' || (payload.sessionId !== null && (typeof payload.sessionId !== 'string' || !/^[A-Za-z0-9][A-Za-z0-9._-]{0,199}$/.test(payload.sessionId)))) throw new Error('Invalid foreground')
      const modern = payload.clientId !== undefined
      if (modern && (typeof payload.clientId !== 'string' || !/^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$/.test(payload.clientId) || !Number.isSafeInteger(payload.seq) || payload.seq < 1)) throw new Error('Invalid foreground client')
      const id = modern ? payload.clientId : legacy, previous = clients.get(id)
      if (modern && previous && payload.seq <= previous.seq) return { ok: true }
      clients.set(id, { sessionId: payload.sessionId, visible: payload.visible, seq: modern ? payload.seq : 0, updatedAt: now() })
      if (clients.size > maxClients) {
        const oldest = [...clients].sort((a, b) => Number(fresh(a[1])) - Number(fresh(b[1])) || a[1].updatedAt - b[1].updatedAt)[0]
        clients.delete(oldest[0])
      }
      return { ok: true }
    },
    current() {
      const active = [...clients.values()].filter(value => fresh(value) && value.sessionId).sort((a, b) => b.updatedAt - a.updatedAt)[0]
      return active ? { sessionId: active.sessionId, visible: true, updatedAt: active.updatedAt } : null
    },
  }
}
