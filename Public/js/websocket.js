/**
 * WebSocket client with auto-reconnect and exponential backoff.
 */
const WS = {
    socket: null,
    token: null,
    reconnectDelay: 1000,
    maxReconnectDelay: 30000,
    listeners: {},
    connected: false,

    /**
     * Connect to the WebSocket server.
     */
    connect(token) {
        this.token = token;
        this.reconnectDelay = 1000;
        this._connect();
    },

    _connect() {
        if (this.socket) {
            this.socket.close();
        }

        const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
        const url = `${protocol}//${window.location.host}/ws?token=${encodeURIComponent(this.token)}`;

        this.socket = new WebSocket(url);

        this.socket.onopen = () => {
            console.log('WebSocket connected');
        };

        this.socket.onmessage = (event) => {
            try {
                const data = JSON.parse(event.data);
                this._handleEvent(data);
            } catch (e) {
                console.error('Failed to parse WebSocket message:', e);
            }
        };

        this.socket.onclose = (event) => {
            console.log('WebSocket disconnected:', event.code, event.reason);
            this.connected = false;
            this._emit('disconnected');
            this._scheduleReconnect();
        };

        this.socket.onerror = (error) => {
            console.error('WebSocket error:', error);
        };
    },

    _handleEvent(event) {
        switch (event.type) {
            case 'connected':
                this.connected = true;
                this.reconnectDelay = 1000;
                this._emit('connected');
                break;
            case 'newMessage':
                this._emit('newMessage', event.data);
                break;
            case 'messageSent':
                this._emit('messageSent', event.data);
                break;
            case 'sendMessageError':
                this._emit('sendMessageError', event.error);
                break;
            case 'error':
                console.error('Server error:', event.error);
                this._emit('error', event.error);
                break;
        }
    },

    _scheduleReconnect() {
        if (!this.token) return;

        console.log(`Reconnecting in ${this.reconnectDelay}ms...`);
        setTimeout(() => {
            this._connect();
        }, this.reconnectDelay);

        // Exponential backoff
        this.reconnectDelay = Math.min(this.reconnectDelay * 2, this.maxReconnectDelay);
    },

    /**
     * Send a message via WebSocket.
     */
    sendMessage({ chatId, address, text, service }) {
        if (!this.socket || this.socket.readyState !== WebSocket.OPEN) {
            console.error('WebSocket not connected');
            return;
        }

        const event = {
            type: 'sendMessage',
            data: { chatId, address, text, service },
        };

        this.socket.send(JSON.stringify(event));
    },

    /**
     * Register an event listener.
     */
    on(event, callback) {
        if (!this.listeners[event]) {
            this.listeners[event] = [];
        }
        this.listeners[event].push(callback);
    },

    /**
     * Remove an event listener.
     */
    off(event, callback) {
        if (!this.listeners[event]) return;
        this.listeners[event] = this.listeners[event].filter(cb => cb !== callback);
    },

    _emit(event, data) {
        const callbacks = this.listeners[event] || [];
        callbacks.forEach(cb => cb(data));
    },

    /**
     * Disconnect and stop reconnecting.
     */
    disconnect() {
        this.token = null;
        if (this.socket) {
            this.socket.close();
            this.socket = null;
        }
    },
};
