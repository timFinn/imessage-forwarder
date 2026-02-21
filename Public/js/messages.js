/**
 * Message view management.
 */
const Messages = {
    currentChatId: null,
    currentChat: null,
    messages: [],
    oldestRowId: null,
    participantMap: {},

    /**
     * Open a conversation and load its messages.
     */
    async open(conv) {
        this.currentChat = conv;
        this.currentChatId = conv.id;
        this.messages = [];
        this.oldestRowId = null;

        // Build participant map for group chats
        this.participantMap = {};
        if (conv.participants) {
            for (const p of conv.participants) {
                this.participantMap[p.id] = p.address;
            }
        }

        document.getElementById('no-chat-selected').hidden = true;
        document.getElementById('new-message-view').hidden = true;
        document.getElementById('chat-view').hidden = false;
        document.getElementById('chat-title').textContent = Conversations.getDisplayName(conv);
        document.getElementById('chat-subtitle').textContent =
            conv.isGroup ? `${conv.participants.length} participants` : (conv.service || '');

        await this.loadMessages();
        this.scrollToBottom();
        document.getElementById('message-input').focus();
    },

    /**
     * Load messages for the current chat.
     */
    async loadMessages(prepend = false) {
        if (!this.currentChatId) return;

        try {
            const msgs = await API.getMessages(this.currentChatId, this.oldestRowId, 50);

            if (prepend && msgs.length > 0) {
                this.messages = [...msgs, ...this.messages];
            } else if (!prepend) {
                this.messages = msgs;
            }

            if (msgs.length > 0) {
                this.oldestRowId = msgs[0].id;
            }

            document.getElementById('load-more-btn').hidden = msgs.length < 50;
            this.render();
        } catch (e) {
            console.error('Failed to load messages:', e);
        }
    },

    /**
     * Render messages in the message list.
     */
    render() {
        const container = document.getElementById('message-list');
        container.innerHTML = '';

        let lastDate = null;

        for (const msg of this.messages) {
            // Date separator
            const msgDate = new Date(msg.date * 1000);
            const dateStr = msgDate.toLocaleDateString([], {
                weekday: 'long', month: 'long', day: 'numeric'
            });

            if (dateStr !== lastDate) {
                const sep = document.createElement('div');
                sep.className = 'date-separator';
                sep.textContent = dateStr;
                container.appendChild(sep);
                lastDate = dateStr;
            }

            const row = document.createElement('div');

            // Determine message type
            if (msg.itemType === 1) {
                // Group event (system message)
                row.className = 'message-row system';
                const bubble = document.createElement('div');
                bubble.className = 'message-bubble';
                bubble.textContent = msg.groupTitle
                    ? `Group name changed to "${msg.groupTitle}"`
                    : (msg.text || 'Group event');
                row.appendChild(bubble);
            } else if (msg.associatedMessageType >= 2000 && msg.associatedMessageType <= 2005) {
                // Tapback
                row.className = 'message-row system';
                const tapback = document.createElement('div');
                tapback.className = 'message-tapback';
                const who = msg.isFromMe ? 'You' : (this.participantMap[msg.handleId] || 'Someone');
                const action = this.getTapbackAction(msg.associatedMessageType);
                tapback.textContent = `${who} ${action} a message`;
                row.appendChild(tapback);
            } else {
                // Regular message
                row.className = `message-row ${msg.isFromMe ? 'sent' : 'received'}`;

                // Show sender name in group chats for received messages
                if (!msg.isFromMe && this.currentChat && this.currentChat.isGroup) {
                    const sender = document.createElement('div');
                    sender.className = 'message-sender';
                    sender.textContent = this.participantMap[msg.handleId] || 'Unknown';
                    row.appendChild(sender);
                }

                if (msg.text) {
                    const bubble = document.createElement('div');
                    bubble.className = 'message-bubble';
                    bubble.textContent = msg.text;
                    row.appendChild(bubble);
                }

                // Attachments
                if (msg.attachments && msg.attachments.length > 0) {
                    for (const att of msg.attachments) {
                        const attEl = document.createElement('div');
                        attEl.className = 'message-attachment';

                        if (att.mimeType && att.mimeType.startsWith('image/')) {
                            const img = document.createElement('img');
                            img.src = API.getAttachmentUrl(att.id);
                            img.alt = att.transferName || 'Image';
                            img.loading = 'lazy';
                            img.addEventListener('click', () => window.open(img.src, '_blank'));
                            attEl.appendChild(img);
                        } else {
                            const link = document.createElement('a');
                            link.href = API.getAttachmentUrl(att.id);
                            link.target = '_blank';
                            link.textContent = att.transferName || att.filename || 'Attachment';
                            attEl.appendChild(link);
                        }

                        row.appendChild(attEl);
                    }
                }

                // If no text and no attachments, show placeholder
                if (!msg.text && (!msg.attachments || msg.attachments.length === 0)) {
                    const bubble = document.createElement('div');
                    bubble.className = 'message-bubble';
                    bubble.textContent = '[unsupported content]';
                    row.appendChild(bubble);
                }

                // Timestamp
                const time = document.createElement('div');
                time.className = 'message-time';
                time.textContent = msgDate.toLocaleTimeString([], {
                    hour: 'numeric', minute: '2-digit'
                });
                row.appendChild(time);
            }

            container.appendChild(row);
        }
    },

    getTapbackAction(type) {
        const actions = {
            2000: 'loved',
            2001: 'liked',
            2002: 'disliked',
            2003: 'laughed at',
            2004: 'emphasized',
            2005: 'questioned',
        };
        return actions[type] || 'reacted to';
    },

    scrollToBottom() {
        const container = document.getElementById('message-container');
        requestAnimationFrame(() => {
            container.scrollTop = container.scrollHeight;
        });
    },

    /**
     * Handle a new real-time message.
     */
    handleNewMessage(message) {
        if (message.chatId !== this.currentChatId) return;

        this.messages.push(message);
        this.render();
        this.scrollToBottom();
    },

    /**
     * Send a message in the current chat.
     */
    async sendMessage(text) {
        if (!this.currentChatId || !text.trim()) return;

        try {
            await API.sendMessage({ chatId: this.currentChatId, text: text.trim() });
        } catch (e) {
            console.error('Failed to send message:', e);
            alert('Failed to send message: ' + e.message);
        }
    },

    /**
     * Close the current chat view.
     */
    close() {
        this.currentChatId = null;
        this.currentChat = null;
        this.messages = [];
        document.getElementById('chat-view').hidden = true;
        document.getElementById('new-message-view').hidden = true;
        document.getElementById('no-chat-selected').hidden = false;
    },
};
