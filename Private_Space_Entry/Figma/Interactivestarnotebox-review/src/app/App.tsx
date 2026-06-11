import React, { useState, useRef, useEffect } from 'react';
import { motion, AnimatePresence, useAnimation, useMotionValue } from 'motion/react';
import { Pen, Mic, ChevronLeft, Check, Image as ImageIcon, Plus, Trash2, Share, Pin, Bookmark, CheckSquare, CheckCircle2, Circle, X, Tag } from 'lucide-react';
import { format } from 'date-fns';
import bgImage from 'figma:asset/db3da22119b54e534176b071715f9791337c4512.png';

type Note = { 
  id: string; 
  text: string; 
  date: string; 
  time: string; 
  pinned?: boolean; 
  categoryName?: string;
  categoryColor?: string;
  categoryBorder?: string;
};

const DEFAULT_CATEGORIES = [
  { id: '1', name: 'Ideas', bg: 'bg-blue-500/20', border: 'border-blue-500/50' },
  { id: '2', name: 'Thoughts', bg: 'bg-purple-500/20', border: 'border-purple-500/50' },
  { id: '3', name: 'Feelings', bg: 'bg-pink-500/20', border: 'border-pink-500/50' },
  { id: '4', name: 'Journal', bg: 'bg-green-500/20', border: 'border-green-500/50' },
  { id: '5', name: 'Uncategorized', bg: 'bg-white/5', border: 'border-yellow-500/20' }
];

const COLORS = [
  { bg: 'bg-red-500/20', border: 'border-red-500/50' },
  { bg: 'bg-orange-500/20', border: 'border-orange-500/50' },
  { bg: 'bg-cyan-500/20', border: 'border-cyan-500/50' },
  { bg: 'bg-indigo-500/20', border: 'border-indigo-500/50' },
  { bg: 'bg-fuchsia-500/20', border: 'border-fuchsia-500/50' },
  { bg: 'bg-rose-500/20', border: 'border-rose-500/50' }
];

export default function App() {
  const [stage, setStage] = useState<'idle' | 'transitioning' | 'notepad' | 'history'>('idle');
  const [targetStage, setTargetStage] = useState<'notepad' | 'history'>('notepad');
  const [notes, setNotes] = useState<Note[]>([]);
  const [noteText, setNoteText] = useState('');
  const [editingNoteId, setEditingNoteId] = useState<string | null>(null);

  // Selection Mode
  const [selectionMode, setSelectionMode] = useState(false);
  const [selectedNotes, setSelectedNotes] = useState<Set<string>>(new Set());
  const [isMarkBoardOpen, setIsMarkBoardOpen] = useState(false);
  const [categories, setCategories] = useState(DEFAULT_CATEGORIES);
  const [newCategoryName, setNewCategoryName] = useState('');
  const [isAddingCategory, setIsAddingCategory] = useState(false);
  const [showDeleteFor, setShowDeleteFor] = useState<string | null>(null);
  const inputRef = useRef<HTMLInputElement>(null);
  const catTimerRef = useRef<NodeJS.Timeout | null>(null);
  const isCatLongPressActive = useRef(false);

  const clearCatTimer = () => {
    if (catTimerRef.current) clearTimeout(catTimerRef.current);
  };

  const handleSaveCategory = () => {
    if (!newCategoryName.trim()) return;
    const randomColor = COLORS[Math.floor(Math.random() * COLORS.length)];
    const newCat = {
      id: Date.now().toString(),
      name: newCategoryName.trim(),
      bg: randomColor.bg,
      border: randomColor.border
    };
    setCategories(prev => {
      const newArr = [...prev];
      const uncatIndex = newArr.findIndex(c => c.name === 'Uncategorized');
      if (uncatIndex !== -1) {
        newArr.splice(uncatIndex, 0, newCat);
      } else {
        newArr.push(newCat);
      }
      return newArr;
    });
    
    setIsAddingCategory(false);
    setNewCategoryName('');
  };

  const textareaRef = useRef<HTMLTextAreaElement>(null);

  useEffect(() => {
    if (isAddingCategory && inputRef.current) {
      inputRef.current.focus();
    }
  }, [isAddingCategory]);

  const handleStarClick = () => {
    if (stage !== 'idle') return;
    setTargetStage(notes.length > 0 ? 'history' : 'notepad');
    setStage('transitioning');
  };

  const focusInput = () => {
    if (textareaRef.current) {
      textareaRef.current.focus();
    }
  };

  const handleBack = () => {
    setNoteText('');
    setEditingNoteId(null);
    if (notes.length > 0) {
      setStage('history');
    } else {
      setStage('idle');
    }
  };

  const handleDone = () => {
    if (noteText.trim()) {
      if (editingNoteId) {
        setNotes(prev => prev.map(n => n.id === editingNoteId ? { ...n, text: noteText.trim(), date: format(new Date(), 'yyyy / MM / dd'), time: format(new Date(), 'HH:mm') } : n));
      } else {
        setNotes(prev => [{
          id: Date.now().toString(),
          text: noteText.trim(),
          date: format(new Date(), 'yyyy / MM / dd'),
          time: format(new Date(), 'HH:mm'),
          pinned: false,
          marked: false
        }, ...prev]);
      }
    }
    setNoteText('');
    setEditingNoteId(null);
    setStage('history');
  };

  const handleAddFromHistory = () => {
    setNoteText('');
    setEditingNoteId(null);
    setStage('notepad');
  };

  const handleEditFromHistory = (note: Note) => {
    setNoteText(note.text);
    setEditingNoteId(note.id);
    setStage('notepad');
  };

  const toggleSelect = (id: string, forceLongPress: boolean = false) => {
    if (forceLongPress && !selectionMode) {
      setSelectionMode(true);
      setSelectedNotes(new Set([id]));
      return;
    }
    setSelectedNotes(prev => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const sortedNotes = [...notes].sort((a, b) => {
    if (a.pinned && !b.pinned) return -1;
    if (!a.pinned && b.pinned) return 1;
    return 0;
  });

  return (
    <div 
      className="relative w-full h-screen max-w-md mx-auto overflow-hidden bg-[#050510] text-white selection:bg-yellow-500/30 shadow-2xl"
      style={{ fontFamily: '-apple-system, BlinkMacSystemFont, "SF Pro", "SF Pro Text", "Segoe UI", Roboto, Helvetica, Arial, sans-serif' }}
    >
      {/* Background Image */}
      <motion.div 
        className="absolute inset-0 z-0"
        animate={{
          filter: stage !== 'idle' ? 'blur(12px) brightness(0.3)' : 'blur(0px) brightness(1)',
          scale: stage !== 'idle' ? 1.1 : 1
        }}
        transition={{ duration: 1.5, ease: "easeInOut" }}
      >
        <img 
          src={bgImage} 
          alt="Galaxy Background" 
          className="w-full h-full object-cover"
        />
      </motion.div>

      {/* The Brightest Star */}
      <AnimatePresence>
        {stage === 'idle' && (
          <motion.button
            className="absolute z-10 w-12 h-12 -ml-6 -mt-6 rounded-full flex items-center justify-center cursor-pointer group"
            style={{ top: '15%', left: '20%' }}
            onClick={handleStarClick}
            initial={{ opacity: 1 }}
            exit={{ opacity: 0, scale: 0, filter: 'blur(10px)' }}
            transition={{ duration: 0.5 }}
            aria-label="Click the brightest star"
          >
            {/* Star core */}
            <motion.div 
              className="absolute w-2 h-2 bg-yellow-100 rounded-full shadow-[0_0_15px_4px_rgba(255,215,0,0.9),0_0_30px_8px_rgba(255,165,0,0.6)]"
              animate={{ opacity: [0.6, 1, 0.6], scale: [0.9, 1.2, 0.9] }}
              transition={{ duration: 3, repeat: Infinity, ease: "easeInOut" }}
            />
            {/* Star flare/rays */}
            <motion.div
              className="absolute w-10 h-[1.5px] bg-gradient-to-r from-transparent via-yellow-200 to-transparent"
              animate={{ opacity: [0.3, 0.9, 0.3], scaleX: [0.7, 1.2, 0.7] }}
              transition={{ duration: 3, repeat: Infinity, ease: "easeInOut" }}
            />
            <motion.div
              className="absolute h-10 w-[1.5px] bg-gradient-to-b from-transparent via-yellow-200 to-transparent"
              animate={{ opacity: [0.3, 0.9, 0.3], scaleY: [0.7, 1.2, 0.7] }}
              transition={{ duration: 3, repeat: Infinity, ease: "easeInOut" }}
            />
          </motion.button>
        )}
      </AnimatePresence>

      {/* Particle Transition */}
      {stage === 'transitioning' && (
        <ParticleTransition onComplete={() => setStage(targetStage)} />
      )}

      {/* Notepad & Icons */}
      <AnimatePresence>
        {stage === 'notepad' && (
          <motion.div
            className="absolute inset-0 z-20 flex flex-col items-center justify-center p-6"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ duration: 1.2, ease: "easeOut" }}
          >
            {/* Notepad container */}
            <motion.div 
              className="relative w-full max-w-sm aspect-[3/4] rounded-xl p-6 flex flex-col backdrop-blur-md border border-yellow-300/40 shadow-[0_0_40px_rgba(255,215,0,0.15)] overflow-hidden"
              initial={{ scale: 0.95, y: 10 }}
              animate={{ scale: 1, y: 0 }}
              transition={{ duration: 1, ease: "easeOut" }}
            >
              {/* Starry texture background for notepad */}
              <div 
                className="absolute inset-0 z-0 bg-[#0a0510]/60 mix-blend-overlay"
                style={{
                  backgroundImage: "radial-gradient(circle at center, rgba(255,220,100,0.25) 1px, transparent 1px), radial-gradient(circle at center, rgba(255,255,255,0.15) 1px, transparent 1px)",
                  backgroundSize: "20px 20px, 14px 14px",
                  backgroundPosition: "0 0, 7px 7px"
                }}
              />
              
              <div className="relative z-10 w-full flex-1 flex flex-col h-full">
                {/* Header */}
                <div className="flex justify-between items-center text-yellow-100/70 text-sm mb-5 border-b border-yellow-500/30 pb-3">
                  <span className="tracking-wider">{format(new Date(), 'yyyy / MM / dd')}</span>
                  <span>{format(new Date(), 'HH:mm')}</span>
                </div>
                
                {/* Text Area */}
                <div className="relative flex-1">
                  {/* Lines */}
                  <div 
                    className="absolute inset-0 pointer-events-none"
                    style={{
                      backgroundImage: "linear-gradient(to bottom, transparent 31px, rgba(255,215,0,0.15) 31px, rgba(255,215,0,0.15) 32px)",
                      backgroundSize: "100% 32px",
                    }}
                  />
                  <textarea
                    ref={textareaRef}
                    value={noteText}
                    onChange={(e) => setNoteText(e.target.value)}
                    className="absolute inset-0 w-full h-full bg-transparent resize-none outline-none text-yellow-50 text-lg font-light placeholder:text-yellow-100/30"
                    style={{
                      lineHeight: "32px",
                      paddingTop: "0px"
                    }}
                    placeholder="Record your thoughts here..."
                  />
                </div>
              </div>

              {/* Glowing edge effect */}
              <div className="absolute inset-0 pointer-events-none rounded-xl shadow-[inset_0_0_40px_rgba(255,215,0,0.1)]" />
            </motion.div>

            {/* Actions */}
            <motion.div 
              className="flex justify-center gap-8 mt-8 w-full max-w-sm px-4"
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.4, duration: 0.8 }}
            >
              <button 
                className="group relative w-12 h-12 rounded-full flex items-center justify-center bg-black/40 border border-yellow-500/30 text-yellow-200 hover:bg-yellow-900/40 hover:text-yellow-100 transition-all shadow-[0_0_20px_rgba(255,215,0,0.1)] hover:shadow-[0_0_30px_rgba(255,215,0,0.25)] backdrop-blur-md overflow-hidden"
              >
                <div className="absolute inset-0 bg-yellow-400/10 opacity-0 group-hover:opacity-100 transition-opacity" />
                <ImageIcon size={20} className="relative z-10" />
              </button>

              <button 
                onClick={focusInput}
                className="group relative w-12 h-12 rounded-full flex items-center justify-center bg-black/40 border border-yellow-500/30 text-yellow-200 hover:bg-yellow-900/40 hover:text-yellow-100 transition-all shadow-[0_0_20px_rgba(255,215,0,0.1)] hover:shadow-[0_0_30px_rgba(255,215,0,0.25)] backdrop-blur-md overflow-hidden"
              >
                <div className="absolute inset-0 bg-yellow-400/10 opacity-0 group-hover:opacity-100 transition-opacity" />
                <Pen size={20} className="relative z-10" />
              </button>
              
              <button 
                onClick={focusInput}
                className="group relative w-12 h-12 rounded-full flex items-center justify-center bg-black/40 border border-yellow-500/30 text-yellow-200 hover:bg-yellow-900/40 hover:text-yellow-100 transition-all shadow-[0_0_20px_rgba(255,215,0,0.1)] hover:shadow-[0_0_30px_rgba(255,215,0,0.25)] backdrop-blur-md overflow-hidden"
              >
                <div className="absolute inset-0 bg-yellow-400/10 opacity-0 group-hover:opacity-100 transition-opacity" />
                <Mic size={20} className="relative z-10" />
              </button>
            </motion.div>

            {/* Top Navigation */}
            <motion.div 
              className="absolute top-0 left-0 right-0 w-full p-6 flex justify-between items-start z-30 pointer-events-none"
              initial={{ opacity: 0, y: -20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.2, duration: 0.8 }}
            >
              {/* Back button */}
              <button 
                onClick={handleBack}
                className="pointer-events-auto group relative w-12 h-12 rounded-full flex items-center justify-center bg-black/40 border border-yellow-500/30 text-yellow-200 hover:bg-yellow-900/40 hover:text-yellow-100 transition-all shadow-[0_0_20px_rgba(255,215,0,0.1)] hover:shadow-[0_0_30px_rgba(255,215,0,0.25)] backdrop-blur-md overflow-hidden"
              >
                <div className="absolute inset-0 bg-yellow-400/10 opacity-0 group-hover:opacity-100 transition-opacity" />
                <ChevronLeft size={22} className="relative z-10" />
              </button>

              {/* Done button */}
              <AnimatePresence>
                {noteText.trim().length > 0 && (
                  <motion.button 
                    initial={{ opacity: 0, scale: 0.8 }}
                    animate={{ opacity: 1, scale: 1 }}
                    exit={{ opacity: 0, scale: 0.8 }}
                    onClick={handleDone}
                    className="pointer-events-auto group relative w-12 h-12 rounded-full flex items-center justify-center bg-yellow-500/20 border border-yellow-400/50 text-yellow-100 hover:bg-yellow-500/40 hover:text-white transition-all shadow-[0_0_20px_rgba(255,215,0,0.2)] hover:shadow-[0_0_30px_rgba(255,215,0,0.4)] backdrop-blur-md overflow-hidden"
                  >
                    <div className="absolute inset-0 bg-yellow-300/20 opacity-0 group-hover:opacity-100 transition-opacity" />
                    <Check size={22} className="relative z-10" />
                  </motion.button>
                )}
              </AnimatePresence>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* History View */}
      <AnimatePresence>
        {stage === 'history' && (
          <motion.div
            className="absolute inset-0 z-20 flex flex-col p-6 pt-20"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.8 }}
          >
            {/* Top Nav for History */}
            <div className="absolute top-0 left-0 right-0 w-full p-6 flex justify-between items-center z-30">
              {!selectionMode ? (
                <button 
                  onClick={() => setStage('idle')}
                  className="group relative w-12 h-12 rounded-full flex items-center justify-center bg-black/40 border border-yellow-500/30 text-yellow-200 hover:bg-yellow-900/40 hover:text-yellow-100 transition-all shadow-[0_0_20px_rgba(255,215,0,0.1)] hover:shadow-[0_0_30px_rgba(255,215,0,0.25)] backdrop-blur-md overflow-hidden"
                >
                  <div className="absolute inset-0 bg-yellow-400/10 opacity-0 group-hover:opacity-100 transition-opacity" />
                  <ChevronLeft size={22} className="relative z-10" />
                </button>
              ) : (
                <button 
                  onClick={() => { setSelectionMode(false); setSelectedNotes(new Set()); }}
                  className="h-10 px-4 rounded-full flex items-center justify-center bg-black/40 border border-yellow-500/30 text-yellow-200 hover:bg-yellow-900/40 backdrop-blur-md text-sm shadow-[0_0_20px_rgba(255,215,0,0.1)]"
                >
                  Cancel
                </button>
              )}
              <div className="flex items-center h-12 px-4 text-yellow-200/70 tracking-widest text-sm">
                {selectionMode ? `${selectedNotes.size} SELECTED` : 'RECORDS'}
              </div>
            </div>

            <div className="flex-1 overflow-y-auto pb-28 space-y-4 pr-2 [&::-webkit-scrollbar]:hidden [-ms-overflow-style:none] [scrollbar-width:none]">
              {sortedNotes.map(note => (
                <SwipeableNoteItem
                  key={note.id}
                  note={note}
                  selectionMode={selectionMode}
                  isSelected={selectedNotes.has(note.id)}
                  onEdit={handleEditFromHistory}
                  onToggleSelect={toggleSelect}
                  onDelete={(id: string) => setNotes(prev => prev.filter(n => n.id !== id))}
                  onShare={() => {}}
                  onPin={(id: string) => setNotes(prev => prev.map(n => n.id === id ? {...n, pinned: !n.pinned} : n))}
                />
              ))}
            </div>

            {/* FAB Add Button */}
            <AnimatePresence>
              {!selectionMode && (
                <motion.button
                  initial={{ opacity: 0, scale: 0.8 }}
                  animate={{ opacity: 1, scale: 1 }}
                  exit={{ opacity: 0, scale: 0.8 }}
                  onClick={handleAddFromHistory}
                  className="absolute bottom-8 right-8 group w-14 h-14 rounded-full flex items-center justify-center bg-yellow-500/20 border border-yellow-400/50 text-yellow-100 hover:bg-yellow-500/40 hover:text-white transition-all shadow-[0_0_20px_rgba(255,215,0,0.2)] hover:shadow-[0_0_30px_rgba(255,215,0,0.4)] backdrop-blur-md overflow-hidden z-30"
                >
                  <div className="absolute inset-0 bg-yellow-300/20 opacity-0 group-hover:opacity-100 transition-opacity" />
                  <Plus size={26} className="relative z-10" />
                </motion.button>
              )}
            </AnimatePresence>

            {/* Bottom Bar for Selection Mode */}
            <AnimatePresence>
              {selectionMode && (
                <motion.div
                  initial={{ y: 100 }}
                  animate={{ y: 0 }}
                  exit={{ y: 100 }}
                  transition={{ duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
                  className="absolute bottom-0 left-0 right-0 p-6 pt-4 pb-8 bg-[#0a0510]/95 backdrop-blur-xl border-t border-yellow-500/30 flex justify-between items-center z-40 shadow-[0_-10px_30px_rgba(0,0,0,0.5)]"
                >
                  <button 
                    onClick={() => { setSelectionMode(false); setSelectedNotes(new Set()); }}
                    className="flex flex-col items-center text-white/80 hover:text-white transition-colors w-16"
                  >
                    <Share size={22} />
                    <span className="text-[10px] mt-2">Share</span>
                  </button>
                  <button 
                    onClick={() => { 
                      setNotes(prev => prev.filter(n => !selectedNotes.has(n.id)));
                      setSelectionMode(false);
                      setSelectedNotes(new Set());
                    }}
                    className="flex flex-col items-center text-white/80 hover:text-white transition-colors w-16"
                  >
                    <Trash2 size={22} />
                    <span className="text-[10px] mt-2">Delete</span>
                  </button>
                  <button 
                    onClick={() => setIsMarkBoardOpen(true)}
                    className="flex flex-col items-center text-white/80 hover:text-white transition-colors w-16"
                  >
                    <Tag size={22} />
                    <span className="text-[10px] mt-2">Mark</span>
                  </button>
                  <button 
                    onClick={() => {
                      if (selectedNotes.size === notes.length) setSelectedNotes(new Set());
                      else setSelectedNotes(new Set(notes.map(n => n.id)));
                    }}
                    className="flex flex-col items-center text-white/80 hover:text-white transition-colors w-16"
                  >
                    <CheckSquare size={22} />
                    <span className="text-[10px] mt-2">All</span>
                  </button>
                </motion.div>
              )}
            </AnimatePresence>

            {/* Classification Board */}
            <AnimatePresence>
              {isMarkBoardOpen && (
                <>
                  <motion.div 
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    exit={{ opacity: 0 }}
                    transition={{ duration: 0.4, ease: "easeOut" }}
                    onClick={() => {
                      setIsMarkBoardOpen(false);
                      setShowDeleteFor(null);
                    }}
                    className="absolute inset-0 bg-black/60 z-40 backdrop-blur-sm"
                  />
                  <motion.div
                    initial={{ y: '100%' }}
                    animate={{ y: 0 }}
                    exit={{ y: '100%' }}
                    transition={{ duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
                    className="absolute bottom-0 left-0 right-0 bg-[#120f1a] rounded-t-3xl p-6 z-50 border-t border-white/10"
                  >
                    <div className="flex justify-between items-center mb-4">
                      <h3 className="text-white font-medium text-lg">Select Category</h3>
                      <button onClick={() => {
                        setIsMarkBoardOpen(false);
                        setIsAddingCategory(false);
                        setNewCategoryName('');
                        setShowDeleteFor(null);
                      }} className="text-white/50 p-2">
                        <X size={20} />
                      </button>
                    </div>
                    <div className="flex flex-col h-[50vh]">
                      <div className="flex-1 overflow-y-auto pb-4 space-y-3 [&::-webkit-scrollbar]:hidden [-ms-overflow-style:none] [scrollbar-width:none]">
                        {categories.map(cat => (
                          <div key={cat.id} className="relative">
                            <AnimatePresence>
                              {showDeleteFor === cat.id && (
                                <>
                                  <div 
                                    className="fixed inset-0 z-40"
                                    onClick={(e) => {
                                      e.stopPropagation();
                                      setShowDeleteFor(null);
                                    }}
                                  />
                                  <motion.div
                                    initial={{ opacity: 0, y: 10, scale: 0.8 }}
                                    animate={{ opacity: 1, y: 0, scale: 1 }}
                                    exit={{ opacity: 0, scale: 0.8 }}
                                    className="absolute -top-12 left-1/2 -translate-x-1/2 bg-red-500/90 backdrop-blur-md text-white px-4 py-2 rounded-xl text-sm shadow-[0_4px_20px_rgba(239,68,68,0.4)] flex items-center gap-2 z-50 cursor-pointer"
                                    onClick={(e) => {
                                      e.stopPropagation();
                                      setCategories(prev => prev.filter(c => c.id !== cat.id));
                                      setShowDeleteFor(null);
                                    }}
                                  >
                                    <Trash2 size={16} />
                                    <span className="font-medium">Delete</span>
                                    <div className="absolute -bottom-2 left-1/2 -translate-x-1/2 border-4 border-transparent border-t-red-500/90" />
                                  </motion.div>
                                </>
                              )}
                            </AnimatePresence>
                            <button
                              onPointerDown={() => {
                                if (showDeleteFor) return;
                                isCatLongPressActive.current = false;
                                catTimerRef.current = setTimeout(() => {
                                  isCatLongPressActive.current = true;
                                  if (cat.name !== 'Uncategorized') {
                                    setShowDeleteFor(cat.id);
                                  }
                                }, 500);
                              }}
                              onPointerUp={clearCatTimer}
                              onPointerLeave={clearCatTimer}
                              onPointerCancel={clearCatTimer}
                              onClick={() => {
                                if (isCatLongPressActive.current || showDeleteFor) return;
                                setNotes(prev => prev.map(n => selectedNotes.has(n.id) ? {
                                  ...n,
                                  categoryName: cat.name === 'Uncategorized' ? undefined : cat.name,
                                  categoryColor: cat.name === 'Uncategorized' ? undefined : cat.bg,
                                  categoryBorder: cat.name === 'Uncategorized' ? undefined : cat.border
                                } : n));
                                setIsMarkBoardOpen(false);
                                setSelectionMode(false);
                                setSelectedNotes(new Set());
                              }}
                              className={`w-full p-4 rounded-xl border flex items-center justify-between gap-2 ${cat.bg} ${cat.border} transition-all active:scale-[0.98] select-none`}
                            >
                              <span className="text-white/90 font-medium">{cat.name}</span>
                            </button>
                          </div>
                        ))}
                        
                        {isAddingCategory && (
                          <div className={`w-full p-3 rounded-xl border flex items-center gap-3 bg-white/5 border-white/20`}>
                            <button
                              onClick={() => {
                                setIsAddingCategory(false);
                                setNewCategoryName('');
                              }}
                              className="text-white/40 hover:text-red-400 p-2 transition-colors shrink-0 rounded-full hover:bg-white/10"
                            >
                              <X size={18} />
                            </button>
                            <input
                              ref={inputRef}
                              type="text"
                              value={newCategoryName}
                              onChange={(e) => setNewCategoryName(e.target.value)}
                              onKeyDown={(e) => {
                                if (e.key === 'Enter') {
                                  handleSaveCategory();
                                } else if (e.key === 'Escape') {
                                  setIsAddingCategory(false);
                                  setNewCategoryName('');
                                }
                              }}
                              placeholder="Category Name"
                              className="flex-1 min-w-0 bg-transparent border-none outline-none text-white/90 font-medium text-center"
                            />
                            <button
                              onClick={handleSaveCategory}
                              className="text-white/40 hover:text-green-400 p-2 transition-colors shrink-0 rounded-full hover:bg-white/10"
                            >
                              <Check size={18} />
                            </button>
                          </div>
                        )}
                      </div>

                      <div className="pt-4 border-t border-white/10 mt-auto bg-[#120f1a]">
                        <button
                          onClick={() => {
                            setIsAddingCategory(true);
                            setTimeout(() => {
                              // Scroll to bottom of the list when adding a new category
                              const listContainer = document.querySelector('.overflow-y-auto');
                              if (listContainer) {
                                listContainer.scrollTop = listContainer.scrollHeight;
                              }
                            }, 50);
                          }}
                          className="w-full p-4 rounded-xl border border-dashed border-white/20 bg-white/5 flex items-center justify-center gap-2 hover:bg-white/10 transition-colors text-white/60"
                        >
                          <Plus size={18} />
                          <span className="font-medium">New Category</span>
                        </button>
                      </div>
                    </div>
                  </motion.div>
                </>
              )}
            </AnimatePresence>

          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}

const ParticleTransition = ({ onComplete }: { onComplete: () => void }) => {
  const [particles, setParticles] = useState<any[]>([]);
  
  useEffect(() => {
    const isMobile = window.innerWidth < 768;
    const particleCount = isMobile ? 60 : 100;

    const newParticles = Array.from({ length: particleCount }).map((_, i) => {
      // Start from edges
      const isLeft = Math.random() > 0.5;
      const startX = isLeft ? -10 - Math.random() * 10 : 110 + Math.random() * 10;
      const startY = -10 + Math.random() * 120;
      
      // Target area: central rect roughly where the notepad will be
      const targetX = 20 + Math.random() * 60;
      const targetY = 25 + Math.random() * 45;
      
      return { 
        id: i, 
        startX, 
        startY, 
        targetX, 
        targetY, 
        delay: Math.random() * 0.5,
        size: Math.random() * 3 + 1.5,
        duration: 0.8 + Math.random() * 0.7 
      };
    });
    setParticles(newParticles);
    
    const t = setTimeout(() => {
      onComplete();
    }, 1600); // Wait for particles to mostly gather before showing notepad
    
    return () => clearTimeout(t);
  }, [onComplete]);

  return (
    <div className="absolute inset-0 pointer-events-none z-20">
      {particles.map(p => (
        <motion.div
          key={p.id}
          className="absolute rounded-full bg-yellow-100 shadow-[0_0_10px_2px_rgba(255,215,0,0.9)]"
          style={{ width: p.size, height: p.size }}
          initial={{ left: `${p.startX}%`, top: `${p.startY}%`, opacity: 0 }}
          animate={{ 
            left: `${p.targetX}%`, 
            top: `${p.targetY}%`, 
            opacity: [0, 1, 1, 0],
            scale: [0.5, 1.2, 0.8, 0]
          }}
          transition={{
            duration: p.duration,
            delay: p.delay,
            ease: "circOut"
          }}
        />
      ))}
    </div>
  );
}

const SwipeableNoteItem = ({ note, onEdit, onToggleSelect, selectionMode, isSelected, onDelete, onShare, onPin }: any) => {
  const controls = useAnimation();
  const x = useMotionValue(0);
  const timerRef = useRef<NodeJS.Timeout | null>(null);
  const isLongPressActive = useRef(false);

  const handleDragEnd = (event: any, info: any) => {
    if (info.offset.x < -60) {
      controls.start({ x: -160 }); // Open to reveal actions on the right
    } else {
      controls.start({ x: 0 }); // Close
    }
  };

  const handlePointerDown = () => {
    if (selectionMode) return;
    isLongPressActive.current = false;
    timerRef.current = setTimeout(() => {
      isLongPressActive.current = true;
      onToggleSelect(note.id, true);
    }, 500);
  };

  const clearTimer = () => {
    if (timerRef.current) clearTimeout(timerRef.current);
  };

  const handleClick = () => {
    if (isLongPressActive.current) {
      isLongPressActive.current = false;
      return;
    }
    
    if (selectionMode) {
      onToggleSelect(note.id);
    } else {
      if (x.get() < -10) {
        controls.start({ x: 0 }); // close swipe if open
      } else {
        onEdit(note);
      }
    }
  };

  return (
    <div className="relative w-full mb-4">
      {/* Background Action Items */}
      <div className="absolute inset-0 bg-yellow-900/30 rounded-2xl flex items-center justify-end px-5 gap-5 z-0 border border-yellow-500/10">
        <button onClick={(e) => { e.stopPropagation(); onPin(note.id); controls.start({x:0}); }} className="p-2 hover:bg-black/20 rounded-full transition-colors z-10 cursor-pointer">
          <Pin className={note.pinned ? "text-white fill-white" : "text-white"} size={20} />
        </button>
        <button onClick={(e) => { e.stopPropagation(); onShare(note.id); }} className="p-2 hover:bg-black/20 rounded-full transition-colors z-10 cursor-pointer">
          <Share className="text-white" size={20} />
        </button>
        <button onClick={(e) => { e.stopPropagation(); onDelete(note.id); }} className="p-2 hover:bg-black/20 rounded-full transition-colors z-10 cursor-pointer">
          <Trash2 className="text-white" size={20} />
        </button>
      </div>

      {/* Draggable Note Surface */}
      <motion.div
        drag={selectionMode ? false : "x"}
        dragConstraints={{ left: -160, right: 0 }}
        dragElastic={0.1}
        dragDirectionLock
        onDragEnd={handleDragEnd}
        animate={controls}
        style={{ x }}
        onPointerDown={handlePointerDown}
        onPointerUp={clearTimer}
        onPointerMove={clearTimer}
        onPointerCancel={clearTimer}
        onClick={handleClick}
        className={`relative z-10 w-full bg-[#0d0a14] border ${note.categoryBorder || 'border-yellow-500/20'} p-5 rounded-2xl shadow-[0_4px_20px_rgba(0,0,0,0.4)] flex items-center cursor-pointer transition-colors overflow-hidden`}
      >
        {note.categoryColor && <div className={`absolute inset-0 pointer-events-none ${note.categoryColor}`} />}
        <div className="relative z-10 flex-1 min-w-0 pointer-events-none">
          <div className="flex justify-between items-center text-yellow-100/50 text-xs mb-3 border-b border-white/10 pb-2">
            <span className="flex items-center gap-2">
              {note.pinned && <Pin size={12} className="text-white fill-white" />}
              {note.categoryName && (
                <span className="px-2 py-0.5 rounded text-[10px] bg-white/20 text-white border border-white/10">
                  {note.categoryName}
                </span>
              )}
              {note.date}
            </span>
            <span>{note.time}</span>
          </div>
          <p className="text-yellow-50/90 font-light leading-relaxed whitespace-pre-wrap break-words line-clamp-4">
            {note.text}
          </p>
        </div>

        {selectionMode && (
          <div className="relative z-10 ml-4 flex-shrink-0 pointer-events-none">
            {isSelected ? <CheckCircle2 className="text-yellow-400" size={24} /> : <Circle className="text-white/30" size={24} />}
          </div>
        )}
      </motion.div>
    </div>
  );
}
