/**
 * REST API client for iMessage Forwarder.
 */
const API = {
    token: null,

    /**
     * Set the auth token for API requests.
     */
    setToken(token) {
        this.token = token;
    },

    /**
     * Make an authenticated API request.
     */
    async request(path, options = {}) {
        const headers = {
            'Authorization': `Bearer ${this.token}`,
            'Content-Type': 'application/json',
            ...options.headers,
        };

        const response = await fetch(path, { ...options, headers });

        if (response.status === 401) {
            throw new Error('unauthorized');
        }

        if (!response.ok) {
            const body = await response.text();
            throw new Error(body || `HTTP ${response.status}`);
        }

        return response.json();
    },

    /**
     * Fetch conversation list.
     */
    async getConversations(offset = 0, limit = 50) {
        return this.request(`/api/conversations?offset=${offset}&limit=${limit}`);
    },

    /**
     * Fetch messages for a conversation.
     * @param {number} chatId
     * @param {number|null} before - ROWID cursor for pagination
     * @param {number} limit
     */
    async getMessages(chatId, before = null, limit = 50) {
        let url = `/api/conversations/${chatId}/messages?limit=${limit}`;
        if (before) url += `&before=${before}`;
        return this.request(url);
    },

    /**
     * Send a message via REST API.
     */
    async sendMessage({ chatId, address, text, service }) {
        return this.request('/api/send', {
            method: 'POST',
            body: JSON.stringify({ chatId, address, text, service }),
        });
    },

    /**
     * Get attachment URL.
     */
    getAttachmentUrl(attachmentId) {
        return `/api/attachments/${attachmentId}`;
    },
};
