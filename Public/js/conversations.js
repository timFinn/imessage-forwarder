/**
 * Conversation list management.
 */
const Conversations = {
    conversations: [],
    selectedId: null,
    onSelect: null,

    /**
     * Load conversations from the API and render the list.
     */
    async load() {
        try {
            this.conversations = await API.getConversations(0, 100);
            this.render();
        } catch (e) {
            console.error('Failed to load conversations:', e);
            if (e.message === 'unauthorized') {
                App.logout();
            }
        }
    },

    /**
     * Get conversation display name.
     */
    getDisplayName(conv) {
        if (conv.displayName) return conv.displayName;
        if (conv.participants && conv.participants.length > 0) {
            return conv.participants.map(p => p.address).join(', ');
        }
        return 'Unknown';
    },

    /**
     * Get initials for avatar.
     */
    getInitials(conv) {
        const name = this.getDisplayName(conv);
        if (name.startsWith('+')) return '#';
        const parts = name.split(/[\s,]+/).filter(Boolean);
        if (parts.length >= 2) {
            return (parts[0][0] + parts[1][0]).toUpperCase();
        }
        return name.substring(0, 2).toUpperCase();
    },

    /**
     * Format a timestamp for the conversation list.
     */
    formatTime(timestamp) {
        if (!timestamp) return '';
        const date = new Date(timestamp * 1000);
        const now = new Date();
        const diff = now - date;

        if (diff < 86400000 && date.getDate() === now.getDate()) {
            return date.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' });
        }
        if (diff < 604800000) {
            return date.toLocaleDateString([], { weekday: 'short' });
        }
        return date.toLocaleDateString([], { month: 'short', day: 'numeric' });
    },

    /**
     * Render the conversation list.
     */
    render() {
        const container = document.getElementById('conversation-list');
        container.innerHTML = '';

        for (const conv of this.conversations) {
            const item = document.createElement('div');
            item.className = 'conversation-item' + (conv.id === this.selectedId ? ' active' : '');
            item.dataset.chatId = conv.id;

            const avatar = document.createElement('div');
            avatar.className = 'conversation-avatar';
            avatar.textContent = this.getInitials(conv);

            const info = document.createElement('div');
            info.className = 'conversation-info';

            const name = document.createElement('div');
            name.className = 'conversation-name';
            name.textContent = this.getDisplayName(conv);

            const preview = document.createElement('div');
            preview.className = 'conversation-preview';
            if (conv.lastMessage) {
                const prefix = conv.lastMessage.isFromMe ? 'You: ' : '';
                preview.textContent = prefix + (conv.lastMessage.text || 'Attachment');
            }

            info.appendChild(name);
            info.appendChild(preview);

            const time = document.createElement('span');
            time.className = 'conversation-time';
            time.textContent = conv.lastMessage ? this.formatTime(conv.lastMessage.date) : '';

            item.appendChild(avatar);
            item.appendChild(info);
            item.appendChild(time);

            item.addEventListener('click', () => {
                this.select(conv.id);
            });

            container.appendChild(item);
        }
    },

    /**
     * Select a conversation.
     */
    select(chatId) {
        this.selectedId = chatId;
        this.render();
        if (this.onSelect) {
            const conv = this.conversations.find(c => c.id === chatId);
            this.onSelect(conv);
        }
    },

    /**
     * Handle a new message by updating the conversation list.
     */
    handleNewMessage(message) {
        if (!message.chatId) return;

        const idx = this.conversations.findIndex(c => c.id === message.chatId);
        if (idx >= 0) {
            // Update existing conversation's last message and move to top
            this.conversations[idx].lastMessage = message;
            const [conv] = this.conversations.splice(idx, 1);
            this.conversations.unshift(conv);
        }
        // If conversation not found, reload the list
        else {
            this.load();
            return;
        }

        this.render();
    },
};
