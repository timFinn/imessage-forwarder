/**
 * Main application controller.
 */
const App = {
    init() {
        this.bindEvents();

        // Check for saved token
        const token = localStorage.getItem('imessage_token');
        if (token) {
            this.authenticate(token);
        }
    },

    bindEvents() {
        // Auth form
        document.getElementById('auth-form').addEventListener('submit', (e) => {
            e.preventDefault();
            const token = document.getElementById('auth-token').value;
            this.authenticate(token);
        });

        // Send form
        document.getElementById('send-form').addEventListener('submit', (e) => {
            e.preventDefault();
            const input = document.getElementById('message-input');
            const text = input.value;
            if (text.trim()) {
                Messages.sendMessage(text);
                input.value = '';
            }
        });

        // New message button
        document.getElementById('new-message-btn').addEventListener('click', () => {
            this.showNewMessage();
        });

        // New message send form
        document.getElementById('new-send-form').addEventListener('submit', (e) => {
            e.preventDefault();
            const address = document.getElementById('new-msg-address').value;
            const text = document.getElementById('new-message-input').value;
            if (address.trim() && text.trim()) {
                this.sendNewMessage(address.trim(), text.trim());
            }
        });

        // Back buttons (mobile)
        document.getElementById('back-btn').addEventListener('click', () => {
            document.getElementById('app').classList.remove('chat-open');
            Messages.close();
            Conversations.selectedId = null;
            Conversations.render();
        });

        document.getElementById('new-msg-back-btn').addEventListener('click', () => {
            document.getElementById('app').classList.remove('chat-open');
            document.getElementById('new-message-view').hidden = true;
            document.getElementById('no-chat-selected').hidden = false;
        });

        // Load more messages
        document.getElementById('load-more-btn').addEventListener('click', () => {
            const container = document.getElementById('message-container');
            const prevHeight = container.scrollHeight;
            Messages.loadMessages(true).then(() => {
                // Maintain scroll position after prepending
                const newHeight = container.scrollHeight;
                container.scrollTop = newHeight - prevHeight;
            });
        });

        // Conversation selection
        Conversations.onSelect = (conv) => {
            if (conv) {
                document.getElementById('app').classList.add('chat-open');
                document.getElementById('new-message-view').hidden = true;
                Messages.open(conv);
            }
        };

        // WebSocket events
        WS.on('connected', () => {
            console.log('Real-time connection established');
        });

        WS.on('newMessage', (message) => {
            Messages.handleNewMessage(message);
            Conversations.handleNewMessage(message);
        });

        WS.on('disconnected', () => {
            console.log('Real-time connection lost, reconnecting...');
        });

        WS.on('error', (error) => {
            if (error === 'Invalid authentication token') {
                this.logout();
            }
        });
    },

    async authenticate(token) {
        API.setToken(token);

        try {
            // Test the token by making an API call
            await API.getConversations(0, 1);

            // Token is valid
            localStorage.setItem('imessage_token', token);
            document.getElementById('auth-screen').hidden = true;
            document.getElementById('app').hidden = false;

            // Connect WebSocket
            WS.connect(token);

            // Load conversations
            Conversations.load();
        } catch (e) {
            if (e.message === 'unauthorized') {
                document.getElementById('auth-error').textContent = 'Invalid token. Please try again.';
                document.getElementById('auth-error').hidden = false;
                localStorage.removeItem('imessage_token');
            } else {
                document.getElementById('auth-error').textContent = 'Connection failed: ' + e.message;
                document.getElementById('auth-error').hidden = false;
            }
        }
    },

    logout() {
        localStorage.removeItem('imessage_token');
        WS.disconnect();
        document.getElementById('app').hidden = true;
        document.getElementById('auth-screen').hidden = false;
        document.getElementById('auth-token').value = '';
        document.getElementById('auth-error').hidden = true;
    },

    showNewMessage() {
        document.getElementById('app').classList.add('chat-open');
        document.getElementById('no-chat-selected').hidden = true;
        document.getElementById('chat-view').hidden = true;
        document.getElementById('new-message-view').hidden = false;
        document.getElementById('new-msg-address').value = '';
        document.getElementById('new-message-input').value = '';
        document.getElementById('new-msg-address').focus();
        Conversations.selectedId = null;
        Conversations.render();
    },

    async sendNewMessage(address, text) {
        try {
            await API.sendMessage({ address, text });
            document.getElementById('new-message-input').value = '';
            // Reload conversations to show the new chat
            setTimeout(() => Conversations.load(), 2000);
        } catch (e) {
            console.error('Failed to send new message:', e);
            alert('Failed to send message: ' + e.message);
        }
    },
};

// Start the app
document.addEventListener('DOMContentLoaded', () => App.init());
