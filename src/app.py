from fastapi import FastAPI

app = FastAPI()

@app.get('/')
def get_root():
    return {"message": "Hello, World!"}

@app.get('/health')
def get_health():
    return {"message": "ok"}