from flask import Flask
from flask_socketio import SocketIO, emit
from flask_cors import CORS
import cv2
import mediapipe as mp
import numpy as np
import logging

app = Flask(__name__)
CORS(app)
CORS(app, resources={r"/api/*": {"origins": "*", "methods": ["GET", "POST"], "allow_headers": ["Content-Type", "Authorization"]}})
socketio = SocketIO(app, cors_allowed_origins="*")

logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

face_mesh = mp.solutions.face_mesh.FaceMesh(refine_landmarks=True)

@socketio.on('connect')
def handle_connect():
    logger.info("Client connected")

@socketio.on('disconnect')
def handle_disconnect():
    logger.info("Client disconnected")

@socketio.on('handle_frame')
def handle_frame(data):
    logger.debug("Received frame data")
    try:
        nparr = np.frombuffer(data, np.uint8)
        frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        if frame is not None:
            gaze_data = process_frame(frame)
            emit('gaze_data', gaze_data)
            logger.debug("Processed frame and sent gaze data")
        else:
            logger.error("Failed to decode frame")
            emit('error', {'message': 'Failed to decode frame'})
    except Exception as e:
        logger.error(f'Error in processing frame: {str(e)}')
        emit('error', {'message': f'Error in processing frame: {str(e)}'})

def process_frame(frame):
    h, w, _ = frame.shape
    rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    results = face_mesh.process(rgb_frame)
    
    if results.multi_face_landmarks:
        landmarks = results.multi_face_landmarks[0].landmark
        left_eye = [landmarks[145], landmarks[159]]
        right_eye = [landmarks[374], landmarks[386]]

        gaze_left_x = sum(landmark.x for landmark in left_eye) / len(left_eye) * w
        gaze_left_y = sum(landmark.y for landmark in left_eye) / len(left_eye) * h
        gaze_right_x = sum(landmark.x for landmark in right_eye) / len(right_eye) * w
        gaze_right_y = sum(landmark.y for landmark in right_eye) / len(right_eye) * h
        
        return {
            'gaze_left_x': gaze_left_x,
            'gaze_left_y': gaze_left_y,
            'gaze_right_x': gaze_right_x,
            'gaze_right_y': gaze_right_y
        }
    logger.warning("Failed to detect eyes")
    return {'error': 'Failed to detect eyes'}

if __name__ == '__main__':
    socketio.run(app, debug=True, host='172.20.10.14', port=3000)
