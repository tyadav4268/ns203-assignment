import csv, time, tkinter as tk
from datetime import datetime, timezone
from pathlib import Path
from tkinter import messagebox

TARGET_SEC, RESPONSE_SEC, ITI_SEC = 5, 6, 1
BLOCKS, TRIALS_PER_BLOCK = 4, 20
IMAGES = ["Apple", "Flower", "Bicycle", "House"]
def now(): return datetime.now(timezone.utc).isoformat(timespec="milliseconds")
def fixation(c): c.delete("all"); c.create_text(125,95,text="+",font=("Arial",56,"bold"),fill="#222")

def draw_choice_icon(c,name):
    c.delete("all"); x,y=75,55
    if name=="Apple":
        c.create_oval(25,15,75,75,fill="#e53935",outline="#922",width=2); c.create_oval(65,15,115,75,fill="#ef5350",outline="#922",width=2); c.create_line(70,18,80,0,width=5,fill="#654321"); c.create_oval(80,0,110,15,fill="#43a047")
    elif name=="Flower":
        c.create_line(70,55,70,100,width=5,fill="#2e7d32")
        for a,b in [(45,25),(70,5),(95,25),(45,50),(95,50)]: c.create_oval(a-13,b-13,a+13,b+13,fill="#ec407a",outline="#ad1457")
        c.create_oval(62,28,78,44,fill="#ffca28")
    elif name=="Bicycle":
        c.create_oval(5,40,50,85,outline="#1565c0",width=4); c.create_oval(90,40,135,85,outline="#1565c0",width=4); c.create_line(27,62,62,20,112,62,27,62,fill="#263238",width=4); c.create_line(62,20,70,62,fill="#263238",width=4)
    else:
        c.create_polygon(5,45,70,0,135,45,fill="#ef5350",outline="#8e2424",width=2); c.create_rectangle(20,45,120,95,fill="#ffcc80",outline="#8d6e63",width=2); c.create_rectangle(60,68,80,95,fill="#795548")

class Receiver:
    def __init__(self):
        self.root=tk.Tk(); self.root.title("ESP Experiment — Receiver"); self.root.geometry("760x620"); self.root.configure(bg="#f4f4f4"); self.index=0; self.response=None; self.build_setup()
    def clear(self):
        for w in self.root.winfo_children(): w.destroy()
    def build_setup(self):
        self.clear(); f=tk.Frame(self.root,bg="#f4f4f4",padx=35,pady=30); f.pack(expand=True)
        tk.Label(f,text="ESP Experiment — Receiver",font=("Arial",23,"bold"),bg="#f4f4f4").pack(pady=15)
        tk.Label(f,text="Pair ID",bg="#f4f4f4").pack(anchor="w"); self.pair=tk.Entry(f,font=("Arial",15),width=30); self.pair.pack(pady=5)
        tk.Label(f,text="Participant label",bg="#f4f4f4").pack(anchor="w"); self.label=tk.Entry(f,font=("Arial",15),width=30); self.label.insert(0,"Receiver"); self.label.pack(pady=5)
        tk.Button(f,text="Continue",font=("Arial",14),command=self.prepare).pack(pady=20)
    def prepare(self):
        self.pair_id=self.pair.get().strip(); self.label_text=self.label.get().strip() or "Receiver"
        if not self.pair_id: messagebox.showerror("Missing Pair ID","Enter the shared Pair ID."); return
        Path("esp_data").mkdir(exist_ok=True); stamp=datetime.now().strftime("%Y%m%d_%H%M%S"); self.path=Path("esp_data")/f"{self.pair_id}_receiver_{stamp}.csv"
        self.file=open(self.path,"w",newline="",encoding="utf-8"); self.writer=csv.DictWriter(self.file,fieldnames=["pair_id","participant_label","block","trial","response","response_time_ms","choice_onset_utc","response_utc"]); self.writer.writeheader(); self.file.flush(); self.instructions()
    def instructions(self):
        self.clear(); f=tk.Frame(self.root,bg="#f4f4f4",padx=35,pady=30); f.pack(expand=True)
        tk.Label(f,text="Instructions",font=("Arial",22,"bold"),bg="#f4f4f4").pack(pady=15)
        tk.Label(f,text="A fixation cross appears for 5 seconds. Then four images appear for 6 seconds. Select the image you believe the sender saw. Your response is recorded immediately, but the trial continues for the full 6 seconds. There are 4 blocks of 20 trials.",wraplength=600,font=("Arial",14),bg="#f4f4f4").pack(pady=15)
        tk.Label(f,text="Coordinate a spoken countdown with the sender. Both click Start at the same agreed moment.",wraplength=580,font=("Arial",12),bg="#f4f4f4").pack(pady=15)
        tk.Button(f,text="Start",font=("Arial",16,"bold"),command=self.start,padx=25,pady=8).pack(pady=20)
    def start(self):
        self.clear(); self.status=tk.Label(self.root,font=("Arial",16,"bold"),bg="#f4f4f4"); self.status.pack(pady=18); self.canvas=tk.Canvas(self.root,width=250,height=190,bg="white"); self.canvas.pack(pady=8); self.timer=tk.Label(self.root,bg="#f4f4f4",font=("Arial",12)); self.timer.pack(pady=5); self.options=tk.Frame(self.root,bg="#f4f4f4"); self.options.pack(pady=10); self.count=3; self.countdown()
    def countdown(self):
        if self.count: self.status.config(text=f"Starting in {self.count}..."); self.count-=1; self.root.after(1000,self.countdown)
        else: self.run_trial()
    def run_trial(self):
        if self.index>=BLOCKS*TRIALS_PER_BLOCK: self.finish(); return
        block=self.index//TRIALS_PER_BLOCK+1; trial=self.index%TRIALS_PER_BLOCK+1; self.status.config(text=f"Block {block}/{BLOCKS} — Trial {trial}/{TRIALS_PER_BLOCK}"); self.timer.config(text="Fixation"); fixation(self.canvas); self.root.after(TARGET_SEC*1000,self.show_choices)
    def show_choices(self):
        self.choice_onset=now(); self.choice_start=time.perf_counter(); self.response=None; self.response_time=""; self.response_utc=""; self.timer.config(text="Choose the image — 6 seconds"); self.canvas.delete("all")
        for w in self.options.winfo_children(): w.destroy()
        for name in IMAGES:
            cell=tk.Frame(self.options,bg="#f4f4f4",padx=5); cell.pack(side="left")
            icon=tk.Canvas(cell,width=140,height=100,bg="white",highlightthickness=1,highlightbackground="#bbb"); icon.pack(); draw_choice_icon(icon,name)
            tk.Button(cell,text=name,font=("Arial",12,"bold"),width=12,command=lambda n=name:self.record(n)).pack(pady=5)
        self.root.after(RESPONSE_SEC*1000,self.end_trial)
    def record(self,name):
        if self.response is not None: return
        self.response=name; self.response_time=round((time.perf_counter()-self.choice_start)*1000,2); self.response_utc=now(); self.timer.config(text=f"Response recorded: {name}. Please wait for the trial to end.")
        for w in self.options.winfo_children():
            for child in w.winfo_children():
                if isinstance(child,tk.Button): child.config(state="disabled")
    def end_trial(self):
        block=self.index//TRIALS_PER_BLOCK+1
        self.writer.writerow(dict(pair_id=self.pair_id,participant_label=self.label_text,block=block,trial=self.index+1,response=self.response or "NO_RESPONSE",response_time_ms=self.response_time,choice_onset_utc=self.choice_onset,response_utc=self.response_utc)); self.file.flush(); self.index+=1
        if self.index<BLOCKS*TRIALS_PER_BLOCK and self.index%TRIALS_PER_BLOCK==0: self.block_break()
        else: fixation(self.canvas); self.timer.config(text="Next trial shortly"); self.root.after(ITI_SEC*1000,self.run_trial)
    def block_break(self):
        self.clear(); f=tk.Frame(self.root,bg="#f4f4f4",padx=30,pady=30); f.pack(expand=True)
        tk.Label(f,text=f"Block {self.index//TRIALS_PER_BLOCK} complete",font=("Arial",22,"bold"),bg="#f4f4f4").pack(pady=20)
        tk.Label(f,text="Take a break. Coordinate with the sender, then both click Start Next Block together.",wraplength=560,font=("Arial",14),bg="#f4f4f4").pack(pady=15)
        tk.Button(f,text="Start Next Block",font=("Arial",15),command=self.start,padx=20,pady=8).pack(pady=20)
    def finish(self):
        self.file.close(); self.clear(); tk.Label(self.root,text=f"Experiment complete\nReceiver data saved to:\n{self.path.resolve()}",font=("Arial",15),bg="#f4f4f4").pack(expand=True)
    def run(self): self.root.mainloop()

if __name__=="__main__": Receiver().run()
