class NotesApp {
    constructor() {
        // Use relative path so requests go to same-origin Nginx which proxies /api to backend service
        this.apiUrl = '/api';
        this.notes = [];
        this.init();
    }

    init() {
        this.bindEvents();
        this.loadNotes();
    }

    bindEvents() {
        const addBtn = document.getElementById('addNoteBtn');
        const titleInput = document.getElementById('noteTitle');
        const contentInput = document.getElementById('noteContent');

        addBtn.addEventListener('click', () => this.addNote());
        
        // Allow Enter key to add note when title is focused
        titleInput.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') {
                contentInput.focus();
            }
        });

        // Allow Ctrl+Enter to add note when content is focused
        contentInput.addEventListener('keypress', (e) => {
            if (e.key === 'Enter' && e.ctrlKey) {
                this.addNote();
            }
        });
    }

    async loadNotes() {
        try {
            this.showLoading();
            const response = await fetch(`${this.apiUrl}/notes`);
            
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }
            
            const data = await response.json();
            this.notes = data.notes || [];
            this.renderNotes();
        } catch (error) {
            console.error('Error loading notes:', error);
            this.showError('Failed to load notes. Please check if the server is running.');
        }
    }

    async addNote() {
        const title = document.getElementById('noteTitle').value.trim();
        const content = document.getElementById('noteContent').value.trim();

        if (!title || !content) {
            alert('Please fill in both title and content');
            return;
        }

        try {
            const response = await fetch(`${this.apiUrl}/notes`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ title, content })
            });

            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }

            const newNote = await response.json();
            this.notes.unshift(newNote);
            this.renderNotes();
            this.clearForm();
        } catch (error) {
            console.error('Error adding note:', error);
            this.showError('Failed to add note. Please try again.');
        }
    }

    async deleteNote(id) {
        if (!confirm('Are you sure you want to delete this note?')) {
            return;
        }

        try {
            const response = await fetch(`${this.apiUrl}/notes/${id}`, {
                method: 'DELETE'
            });

            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }

            this.notes = this.notes.filter(note => note.id !== id);
            this.renderNotes();
        } catch (error) {
            console.error('Error deleting note:', error);
            this.showError('Failed to delete note. Please try again.');
        }
    }

    renderNotes() {
        const container = document.getElementById('notesContainer');
        
        if (this.notes.length === 0) {
            container.innerHTML = `
                <div class="empty-state">
                    <h3>No notes yet</h3>
                    <p>Create your first note above!</p>
                </div>
            `;
            return;
        }

        container.innerHTML = this.notes.map(note => `
            <div class="note">
                <div class="note-header">
                    <h3 class="note-title">${this.escapeHtml(note.title)}</h3>
                    <span class="note-date">${this.formatDate(note.created_at)}</span>
                </div>
                <div class="note-content">${this.escapeHtml(note.content)}</div>
                <div class="note-actions">
                    <button class="delete-btn" onclick="app.deleteNote('${note.id}')">
                        Delete
                    </button>
                </div>
            </div>
        `).join('');
    }

    showLoading() {
        const container = document.getElementById('notesContainer');
        container.innerHTML = `
            <div class="loading">
                <p>Loading notes...</p>
            </div>
        `;
    }

    showError(message) {
        const container = document.getElementById('notesContainer');
        container.innerHTML = `
            <div class="error">
                <p>${message}</p>
                <button onclick="app.loadNotes()" style="margin-top: 10px; padding: 5px 10px;">
                    Try Again
                </button>
            </div>
        `;
    }

    clearForm() {
        document.getElementById('noteTitle').value = '';
        document.getElementById('noteContent').value = '';
        document.getElementById('noteTitle').focus();
    }

    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    formatDate(dateString) {
        const date = new Date(dateString);
        return date.toLocaleDateString() + ' ' + date.toLocaleTimeString([], {
            hour: '2-digit',
            minute: '2-digit'
        });
    }
}

// Initialize the app when the DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.app = new NotesApp();
});
