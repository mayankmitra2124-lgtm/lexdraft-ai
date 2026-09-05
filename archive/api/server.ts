import express from 'express';
import multer from 'multer';
import cors from 'cors';
import axios from 'axios';
import FormData from 'form-data';
import path from 'path';

const app = express();
app.use(cors());

// Serve the original Vanilla JS UI to maintain the exact look and feel
app.use(express.static(path.join(__dirname, '../../public')));

// Configure multer for streaming
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 4 * 1024 * 1024 * 1024 } });

app.post('/api/upload', upload.single('file'), async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ error: 'No file uploaded' });
        }

        const formData = new FormData();
        formData.append('file', req.file.buffer, req.file.originalname);

        const processorUrl = process.env.PROCESSOR_URL || 'http://localhost:8000/api/v1/ingest';
        
        const response = await axios.post(processorUrl, formData, {
            headers: {
                ...formData.getHeaders(),
            },
            maxContentLength: Infinity,
            maxBodyLength: Infinity,
        });

        res.status(202).json({
            message: 'File streamed to AI processor successfully',
            evidenceId: response.data.evidence_id,
            status: response.data.status
        });
    } catch (error: any) {
        console.error('Error proxying to FastAPI processor:', error.message);
        res.status(500).json({ error: 'Failed to process file' });
    }
});

app.get('/api/progress/:evidenceId', (req, res) => {
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');

    const interval = setInterval(() => {
        res.write(`data: ${JSON.stringify({ status: 'PROCESSING', progress: Math.random() * 100 })}\n\n`);
    }, 2000);

    req.on('close', () => {
        clearInterval(interval);
        res.end();
    });
});

const PORT = process.env.PORT || 8080;
app.listen(PORT, () => {
    console.log(`Node Gateway API serving original UI on port ${PORT}`);
});
