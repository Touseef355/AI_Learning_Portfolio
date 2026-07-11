import cv2
from detector import detect_plate
from ultralytics import YOLO
import time
import requests  
import os
from dotenv import load_dotenv
import base64
from collections import Counter
load_dotenv("../backend/.env")

# Django Exit API URL
API_URL = "http://127.0.0.1:8000/api/ai/exit/"  
API_KEY = os.getenv("EXIT_CAMERA_API_KEY")
car_model = YOLO("yolov8n.pt")


def is_vehicle_in_roi(roi):
    results = car_model(roi, conf=0.6, verbose=False, imgsz=320)
    for box in results[0].boxes:
        if int(box.cls[0]) in [2, 3, 7]:
            x1, y1, x2, y2 = map(int, box.xyxy[0])
            box_area = (x2 - x1) * (y2 - y1)
            roi_area = roi.shape[0] * roi.shape[1]
            ratio = box_area / roi_area
            if ratio > 0.55:  
                if int(box.cls[0]) == 2:
                    return True, "car"
                elif int(box.cls[0]) == 3:
                    return True, "motorcycle"
                elif int(box.cls[0]) == 7:
                    return True, "truck"
    return False, None

def capture_images(cap, ROI_X1, ROI_X2, ROI_Y1, ROI_Y2):
    images = []
    for i in range(5):
        ret, frame = cap.read()
        if ret:
            roi = frame[ROI_Y1:ROI_Y2, ROI_X1:ROI_X2]
            images.append(roi)
        time.sleep(0.1)
    return images

def best_result(results):
    successful = [r for r in results if r["success"] == True]
    if not successful:
        return {"success": False, "error": "No plate detected"}
    best = max(successful, key=lambda x: x["yolo_confidence"])
    return best

def run_camera():
    roi_occupied = False
    last_plate = ""

    consecutive_frames = 0
    no_vehicle_frames = 0

    vehicle_present = False
    last_vehicle_state = False

    capture_lock = False
    capture_cooldown = 5
    last_capture_time = 0

    cap = cv2.VideoCapture(0)

    if not cap.isOpened():
        print("No camera found")
        return

    print("Exit Camera Opened!")  

    frame_count = 0

    while True:
        ret, frame = cap.read()
        if not ret:
            break

        frame_count += 1
        height, width = frame.shape[:2]

        ROI_X1 = int(width * 0)
        ROI_Y1 = int(height * 0.20)
        ROI_X2 = int(width * 1)
        ROI_Y2 = int(height * 0.90)

        roi = frame[ROI_Y1:ROI_Y2, ROI_X1:ROI_X2]

        color = (0, 255, 0)
        label = "Exit Gate Detection"  

        # Detection every 3 frames for performance
        if frame_count % 3 == 0:
            vehicle_present, vehicle_type = is_vehicle_in_roi(roi)
            last_vehicle_state = vehicle_present
        else:
            vehicle_present = last_vehicle_state

        # Frame counters
        if vehicle_present:
            consecutive_frames += 1
            no_vehicle_frames = 0
        else:
            consecutive_frames = 0
            no_vehicle_frames += 1

        color = (0, 0, 255) if vehicle_present else (0, 255, 0)
        label = "Vehicle Detected!" if vehicle_present else "No Vehicle Detected"

        cv2.rectangle(frame, (ROI_X1, ROI_Y1), (ROI_X2, ROI_Y2), color, 2)
        cv2.putText(
            frame,
            label,
            (ROI_X1, ROI_Y1 - 10),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.7,
            color,
            2,
        )

        current_time = time.time()

        # VEHICLE DETECTED AT EXIT
        if consecutive_frames >= 3 and not roi_occupied:

            print("Car at exit gate") 
            roi_occupied = True

            # Capture consecutive frames
            images = capture_images(cap, ROI_X1, ROI_X2, ROI_Y1, ROI_Y2)
            results = []

            # Detect plates on each frame — dont delete yet
            for idx, img in enumerate(images):
                temp_path = f"temp{idx}.jpg"
                cv2.imwrite(temp_path, img)
                detection = detect_plate(temp_path)
                results.append(detection)

            # Aggregate most common plate
            detected_frames = [
                r["plate_number"] for r in results 
                if r["success"]
                and any(c.isalpha() for c in r["plate_number"])
            ]

            if detected_frames:
                last_plate = Counter(detected_frames).most_common(1)[0][0]
                best = best_result(results)
                confidence = best["yolo_confidence"]

                # Get best image and convert to base64
                best_idx = results.index(best)
                best_img_path = f"temp{best_idx}.jpg"

                with open(best_img_path, 'rb') as f:
                    image_base64 = base64.b64encode(f.read()).decode('utf-8')

                # Get cropped plate from best result
                cropped_base64 = best.get("cropped_plate", "")
                print(f"Final Plate (aggregated): {last_plate}")

                try:
                    response = requests.post(
                        API_URL,
                        data={
                            "plate_number": last_plate,
                            "confidence"  : confidence,
                            "vehicle_type": vehicle_type,
                            "gate"        : "Exit Gate",  
                            "image"       : image_base64,
                            "cropped_plate": cropped_base64,
                        },
                        headers={"X-API-Key": API_KEY}
                    )
                    print("Exit API Response", response.json())
                except Exception as e:
                    print("Exit API error", e)

            else:
                print("No plate detected in frames")

            # Delete all temp files after API call
            for idx in range(len(images)):
                temp_path = f"temp{idx}.jpg"
                if os.path.exists(temp_path):
                    os.remove(temp_path)

        # VEHICLE LEFT EXIT ROI
        if no_vehicle_frames >= 10 and roi_occupied:
            print("Car passed exit gate")  
            roi_occupied = False
            no_vehicle_frames = 0

        # CAPTURE COOLDOWN RESET
        if capture_lock and (current_time - last_capture_time > capture_cooldown):
            capture_lock = False

        cv2.imshow("EXIT GATE - SMART PARKING", frame)  

        key = cv2.waitKey(1) & 0xFF
        if key == ord("q") or key == ord("Q"):
            break

    cap.release()
    cv2.destroyAllWindows()

if __name__ == "__main__":
    run_camera()