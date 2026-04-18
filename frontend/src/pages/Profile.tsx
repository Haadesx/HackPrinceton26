import { useEffect, useMemo, useRef, useState } from "react";
import { motion } from "framer-motion";
import {
  Award,
  Calendar as CalendarIcon,
  ChevronDown,
  FileText,
  GraduationCap,
  Hash,
  Search,
  University,
  Upload,
  User,
} from "lucide-react";

import { Particles } from "@/components/background/Particles";
import { apiGet, apiPostFormData } from "@/lib/api";
import { useAppStore } from "@/store/useAppStore";
import type {
  Course,
  OfficialCatalogCourse,
  TranscriptImportResponse,
  UniversityCatalogResponse,
  UniversityProfileResponse,
  UniversitySearchResult,
} from "@/types";

export function Profile() {
  const storeCourses = useAppStore((s) => s.courses);
  const [selectedSemester, setSelectedSemester] = useState("");
  const [universityQuery, setUniversityQuery] = useState("Rutgers");
  const [universityResults, setUniversityResults] = useState<UniversitySearchResult[]>([]);
  const [selectedUniversity, setSelectedUniversity] = useState<UniversitySearchResult | null>(null);
  const [universityProfile, setUniversityProfile] = useState<UniversityProfileResponse | null>(null);
  const [profileLoading, setProfileLoading] = useState(false);
  const [catalog, setCatalog] = useState<UniversityCatalogResponse | null>(null);
  const [catalogLoading, setCatalogLoading] = useState(false);
  const [catalogError, setCatalogError] = useState<string | null>(null);
  const [transcriptImport, setTranscriptImport] = useState<TranscriptImportResponse | null>(null);
  const [uploading, setUploading] = useState(false);
  const [uploadError, setUploadError] = useState<string | null>(null);
  const fileInputRef = useRef<HTMLInputElement | null>(null);

  const getSemesterStr = (course: Course) => {
    if (!course.start_at) return "Unknown Semester";
    const d = new Date(course.start_at);
    const year = d.getFullYear();
    const month = d.getMonth();
    if (month < 5) return `Spring ${year}`;
    if (month < 8) return `Summer ${year}`;
    return `Fall ${year}`;
  };

  const getGrade = (course: Course) => {
    if (course.grade) return course.grade;
    if (course.progress === 0) return "TBD";
    if (course.progress >= 97) return "A+";
    if (course.progress >= 93) return "A";
    if (course.progress >= 90) return "A-";
    if (course.progress >= 87) return "B+";
    if (course.progress >= 83) return "B";
    if (course.progress >= 80) return "B-";
    if (course.progress >= 77) return "C+";
    if (course.progress >= 73) return "C";
    if (course.progress >= 70) return "C-";
    if (course.progress >= 65) return "D+";
    if (course.progress >= 60) return "D";
    return "F";
  };

  const courseData = useMemo(() => {
    const data: Record<string, Course[]> = {};
    storeCourses.forEach((c) => {
      const sem = getSemesterStr(c);
      if (!data[sem]) data[sem] = [];
      data[sem].push(c);
    });
    return data;
  }, [storeCourses]);

  const semesters = useMemo(() => {
    return Object.keys(courseData).sort((a, b) => {
      if (a === "Unknown Semester") return 1;
      if (b === "Unknown Semester") return -1;
      const [seasonA, yearA] = a.split(" ");
      const [seasonB, yearB] = b.split(" ");
      if (yearA !== yearB) return parseInt(yearB) - parseInt(yearA);
      const order: Record<string, number> = { Fall: 3, Summer: 2, Spring: 1 };
      return order[seasonB] - order[seasonA];
    });
  }, [courseData]);

  useEffect(() => {
    if ((!selectedSemester || !semesters.includes(selectedSemester)) && semesters.length > 0) {
      setSelectedSemester(semesters[0]);
    }
  }, [semesters, selectedSemester]);

  useEffect(() => {
    void handleUniversitySearch("Rutgers");
  }, []);

  useEffect(() => {
    if (!selectedUniversity) return;
    void loadUniversityProfile(selectedUniversity.slug);
    if (selectedUniversity.catalog_supported) {
      void loadCatalog(selectedUniversity.slug);
    } else {
      setCatalog(null);
      setTranscriptImport(null);
    }
  }, [selectedUniversity]);

  const currentCourses = courseData[selectedSemester] || [];
  const importedCourses = useMemo<Course[]>(
    () =>
      (transcriptImport?.matched_courses ?? []).map((course) => ({
        ...course,
        color: selectedUniversity?.color ?? "#A41E35",
      })),
    [selectedUniversity?.color, transcriptImport?.matched_courses],
  );
  const activeCourses = importedCourses.length > 0 ? importedCourses : currentCourses;
  const activeCatalogPreview = (catalog?.courses ?? []).slice(0, 6);
  const canImportTranscript = Boolean(selectedUniversity?.transcript_supported);

  async function handleUniversitySearch(queryOverride?: string) {
    const q = (queryOverride ?? universityQuery).trim();
    try {
      const response = await apiGet<{ results: UniversitySearchResult[] }>(
        `/universities/search${q ? `?q=${encodeURIComponent(q)}` : ""}`,
      );
      setUniversityResults(response.results);
      setCatalogError(null);
      if (!selectedUniversity && response.results.length > 0) {
        const preferred =
          response.results.find((item) => item.slug === "rutgers") ?? response.results[0];
        setSelectedUniversity(preferred);
      }
    } catch (error) {
      setCatalogError(error instanceof Error ? error.message : "Failed to search universities.");
    }
  }

  async function loadCatalog(slug: string) {
    try {
      setCatalogLoading(true);
      setCatalogError(null);
      const response = await apiGet<UniversityCatalogResponse>(`/universities/${slug}/catalog`);
      setCatalog(response);
    } catch (error) {
      setCatalogError(error instanceof Error ? error.message : "Failed to load official catalog.");
    } finally {
      setCatalogLoading(false);
    }
  }

  async function loadUniversityProfile(slug: string) {
    try {
      setProfileLoading(true);
      const response = await apiGet<UniversityProfileResponse>(`/universities/${slug}/profile`);
      setUniversityProfile(response);
    } catch {
      setUniversityProfile(null);
    } finally {
      setProfileLoading(false);
    }
  }

  async function handleTranscriptUpload(file: File) {
    if (!selectedUniversity) {
      setUploadError("Pick a university source first.");
      return;
    }
    if (!selectedUniversity.transcript_supported) {
      setUploadError("Transcript import is not supported yet for this university.");
      return;
    }

    try {
      setUploading(true);
      setUploadError(null);
      const formData = new FormData();
      formData.append("file", file);
      formData.append("university_slug", selectedUniversity.slug);
      const response = await apiPostFormData<TranscriptImportResponse>("/transcript/import", formData);
      setTranscriptImport(response);
    } catch (error) {
      setUploadError(error instanceof Error ? error.message : "Transcript import failed.");
    } finally {
      setUploading(false);
      if (fileInputRef.current) {
        fileInputRef.current.value = "";
      }
    }
  }

  return (
    <div className="h-full relative overflow-hidden syllara-hub-bg">
      <div className="absolute inset-0 z-0 pointer-events-none syllara-mesh-overlay" />
      <Particles className="z-[1]" quantity={100} staticity={55} ease={60} size={0.4} color="#ffffff" />

      <div className="relative z-10 flex flex-col h-full overflow-y-auto">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, ease: [0.32, 0.72, 0, 1] }}
          className="mx-auto px-8 relative z-20 max-w-6xl w-full pt-16 pb-24"
        >
          <div className="flex items-center gap-4 mb-10">
            <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-[#CC0033] to-[#A41E35] flex items-center justify-center shrink-0 glow-indigo border border-white/10">
              <User size={32} className="text-white" />
            </div>
            <div>
              <div className="flex items-center gap-3 mb-1">
                <div className="w-1.5 h-1.5 rounded-full bg-[#CC0033] animate-pulse" />
                <span className="text-[10px] font-mono tracking-[0.2em] text-white/30 uppercase">
                  Student Profile
                </span>
              </div>
              <h1 className="text-3xl font-medium text-white/95 tracking-tight">Jane Doe</h1>
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
            <div className="command-brief-card rounded-2xl p-6 flex flex-col transition-all hover:bg-white/[0.04]">
              <div className="flex items-center gap-3 mb-4 text-white/40">
                <Hash size={18} />
                <span className="text-xs font-mono tracking-wider uppercase">University ID</span>
              </div>
              <span className="text-2xl font-medium text-white/90">123456789</span>
            </div>

            <div className="command-brief-card rounded-2xl p-6 flex flex-col transition-all hover:bg-white/[0.04]">
              <div className="flex items-center gap-3 mb-4 text-white/40">
                <GraduationCap size={18} />
                <span className="text-xs font-mono tracking-wider uppercase">Academic Year</span>
              </div>
              <span className="text-xl font-medium text-white/90">
                {transcriptImport ? "Transcript Imported" : "Graduate Student"}
              </span>
              <span className="text-sm text-white/40 mt-1">
                {selectedUniversity?.name ?? "Select a university source"}
              </span>
            </div>

            <div className="command-brief-card rounded-2xl p-6 flex flex-col transition-all hover:bg-white/[0.04]">
              <div className="flex items-center gap-3 mb-4 text-white/40">
                <Award size={18} />
                <span className="text-xs font-mono tracking-wider uppercase">Imported Courses</span>
              </div>
              <span className="text-2xl font-medium text-[#CC0033]">
                {transcriptImport?.match_count ?? currentCourses.length}
              </span>
              <span className="text-sm text-white/40 mt-1">
                {transcriptImport ? "Matched against official catalog" : "Local semester snapshot"}
              </span>
            </div>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
            <div className="lg:col-span-2 space-y-6">
              <div className="command-brief-card rounded-2xl p-8">
                <div className="flex flex-col sm:flex-row sm:items-center justify-between mb-8 gap-4">
                  <div className="flex items-center gap-3">
                    <CalendarIcon size={20} className="text-[#CC0033]" />
                    <div>
                      <h2 className="text-lg font-medium text-white/90">Academic History</h2>
                      <p className="text-xs text-white/40 mt-1">
                        {transcriptImport
                          ? `${transcriptImport.university.name} transcript matched to official course pages`
                          : "Fallback semester data"}
                      </p>
                    </div>
                  </div>

                  {!transcriptImport && semesters.length > 0 && (
                    <div className="relative">
                      <select
                        value={selectedSemester}
                        onChange={(e) => setSelectedSemester(e.target.value)}
                        className="appearance-none bg-white/[0.03] border border-white/[0.08] hover:border-white/[0.15] rounded-xl px-4 py-2 pr-10 text-sm text-white/80 focus:outline-none focus:border-white/20 transition-all w-full sm:w-auto"
                      >
                        {semesters.map((s) => (
                          <option key={s} value={s} className="bg-[#0d0a0a] text-white/90">
                            {s}
                          </option>
                        ))}
                      </select>
                      <ChevronDown
                        size={14}
                        className="absolute right-3 top-1/2 -translate-y-1/2 text-white/40 pointer-events-none"
                      />
                    </div>
                  )}
                </div>

                <div className="space-y-3">
                  {activeCourses.length === 0 ? (
                    <p className="text-sm text-white/40 italic">
                      {transcriptImport
                        ? "No courses from the transcript matched the selected university catalog."
                        : "No courses found for this semester."}
                    </p>
                  ) : (
                    activeCourses.map((course, i) => {
                      const grade = getGrade(course);
                      const badgeClass =
                        grade === "TBD"
                          ? "text-white/40 text-xs bg-white/[0.03] border-white/[0.06]"
                          : "text-[#CC0033] bg-[#CC0033]/10 border-[#CC0033]/20";
                      return (
                        <motion.div
                          key={`${course.id}-${selectedSemester}`}
                          initial={{ opacity: 0, x: -10 }}
                          animate={{ opacity: 1, x: 0 }}
                          transition={{ delay: i * 0.06, duration: 0.35 }}
                          className="flex items-center justify-between p-4 rounded-xl bg-white/[0.02] border border-white/[0.04] hover:bg-white/[0.06] hover:border-white/[0.08] transition-all group"
                        >
                          <div className="flex items-center gap-4 min-w-0">
                            <div className="w-12 h-12 rounded-lg bg-white/[0.03] border border-white/[0.06] flex items-center justify-center shrink-0 group-hover:bg-white/[0.05] transition-colors">
                              <span className="text-xs font-mono text-white/60">
                                {course.course_code.replace(/\D/g, "").slice(-3)}
                              </span>
                            </div>
                            <div className="min-w-0">
                              <h3 className="text-white/90 font-medium group-hover:text-white transition-colors">
                                {course.course_code}
                              </h3>
                              <p className="text-sm text-white/40 group-hover:text-white/50 transition-colors truncate">
                                {course.name}
                              </p>
                              {"transcript_line" in course && typeof course.transcript_line === "string" && (
                                <p className="text-xs text-white/35 mt-1 truncate">{course.transcript_line}</p>
                              )}
                            </div>
                          </div>
                          <div
                            className={`flex items-center justify-center min-w-[3rem] h-10 px-3 rounded-full font-medium border shadow-[0_0_10px_rgba(255,143,0,0.1)] ${badgeClass}`}
                          >
                            {grade}
                          </div>
                        </motion.div>
                      );
                    })
                  )}
                </div>
              </div>
            </div>

            <div className="space-y-6">
              <div className="command-brief-card rounded-2xl p-8">
                <div className="flex items-center gap-3 mb-6">
                  <University size={20} className="text-[#CC0033]" />
                  <h2 className="text-lg font-medium text-white/90">Official University Sources</h2>
                </div>

                <div className="space-y-4">
                  <div className="flex gap-2">
                    <div className="relative flex-1">
                      <Search
                        size={14}
                        className="absolute left-3 top-1/2 -translate-y-1/2 text-white/35 pointer-events-none"
                      />
                      <input
                        value={universityQuery}
                        onChange={(e) => setUniversityQuery(e.target.value)}
                        placeholder="Search Rutgers, MIT, Princeton..."
                        className="w-full rounded-xl bg-white/[0.03] border border-white/[0.08] pl-9 pr-3 py-2.5 text-sm text-white/85 placeholder:text-white/30 focus:outline-none focus:border-[#CC0033]/40"
                        onKeyDown={(e) => {
                          if (e.key === "Enter") {
                            void handleUniversitySearch();
                          }
                        }}
                      />
                    </div>
                    <button
                      onClick={() => void handleUniversitySearch()}
                      className="px-4 rounded-xl bg-[#CC0033]/15 border border-[#CC0033]/20 text-[#FFD08A] text-sm hover:bg-[#CC0033]/20 transition-colors"
                    >
                      Search
                    </button>
                  </div>

                  <div className="space-y-2">
                    {universityResults.map((result) => {
                      const active = selectedUniversity?.slug === result.slug;
                      return (
                        <button
                          key={result.slug}
                          onClick={() => setSelectedUniversity(result)}
                          className={`w-full text-left rounded-xl border px-4 py-3 transition-all ${
                            active
                              ? "border-[#CC0033]/40 bg-[#CC0033]/10"
                              : "border-white/[0.08] bg-white/[0.03] hover:bg-white/[0.05]"
                          }`}
                        >
                          <div className="flex items-center justify-between gap-3">
                            <div>
                              <div className="text-sm font-medium text-white/90">{result.name}</div>
                              <div className="text-xs text-white/40 mt-1">
                                {result.official_domain} • {result.location}
                              </div>
                              <div className="text-[11px] text-white/30 mt-1">
                                {result.catalog_supported ? "Catalog import available" : "Official homepage only"}
                              </div>
                            </div>
                            <div
                              className="w-2.5 h-2.5 rounded-full shrink-0"
                              style={{ backgroundColor: result.color }}
                            />
                          </div>
                        </button>
                      );
                    })}
                  </div>

                  {catalogError && <p className="text-xs text-[#FFCDD6]">{catalogError}</p>}

                  <div className="rounded-xl border border-white/[0.08] bg-white/[0.03] p-4">
                    <div className="flex items-center justify-between gap-3 mb-3">
                      <div>
                        <div className="text-sm font-medium text-white/90">
                          {selectedUniversity?.short_name ?? "No university selected"}
                        </div>
                        <div className="text-xs text-white/40 mt-1">
                          {profileLoading
                            ? "Loading official homepage..."
                            : universityProfile?.homepage_title ?? "Choose a source to load its official homepage"}
                        </div>
                      </div>
                      {selectedUniversity?.catalog_supported && (
                        <button
                          onClick={() => void loadCatalog(selectedUniversity.slug)}
                          className="px-3 py-2 rounded-lg border border-white/[0.08] text-xs text-white/70 hover:bg-white/[0.05]"
                        >
                          Refresh
                        </button>
                      )}
                    </div>

                    <div className="rounded-lg border border-white/[0.06] bg-black/10 px-3 py-3 mb-3">
                      <div className="text-xs uppercase tracking-[0.18em] text-white/30 mb-2">
                        Official Profile
                      </div>
                      <div className="text-sm text-white/85">
                        {universityProfile?.homepage_description ?? selectedUniversity?.description}
                      </div>
                      {selectedUniversity && (
                        <a
                          href={selectedUniversity.homepage_url}
                          target="_blank"
                          rel="noreferrer"
                          className="inline-flex mt-3 text-xs text-[#FFD08A] hover:text-white transition-colors"
                        >
                          Open official website
                        </a>
                      )}
                    </div>

                    <div className="flex items-center justify-between gap-3 mb-3">
                      <div className="text-xs text-white/40">
                        {selectedUniversity?.catalog_supported
                          ? catalogLoading
                            ? "Loading official course catalog..."
                            : catalog
                              ? `${catalog.courses.length} official courses loaded`
                              : "Catalog ready to load"
                          : "Catalog import not wired for this school yet"}
                      </div>
                      {selectedUniversity && !selectedUniversity.catalog_supported && (
                        <span className="text-[11px] text-white/30">Homepage search still works</span>
                      )}
                    </div>

                    <div className="space-y-2">
                      {activeCatalogPreview.map((course: OfficialCatalogCourse) => (
                        <a
                          key={course.id}
                          href={course.catalog_url}
                          target="_blank"
                          rel="noreferrer"
                          className="block rounded-lg border border-white/[0.06] bg-black/10 px-3 py-2 hover:bg-white/[0.05] transition-colors"
                        >
                          <div className="text-xs font-mono text-[#FFD08A]">{course.course_code}</div>
                          <div className="text-sm text-white/85 mt-1">{course.name}</div>
                        </a>
                      ))}
                      {activeCatalogPreview.length === 0 && (
                        <div className="text-xs text-white/35 rounded-lg border border-white/[0.06] bg-black/10 px-3 py-3">
                          Search works for many universities. Official course import is currently enabled for Rutgers and Princeton.
                        </div>
                      )}
                    </div>
                  </div>
                </div>
              </div>

              <div className="command-brief-card rounded-2xl p-8">
                <div className="flex items-center gap-3 mb-6">
                  <FileText size={20} className="text-[#CC0033]" />
                  <h2 className="text-lg font-medium text-white/90">Documents</h2>
                </div>

                <div className="space-y-4">
                  {transcriptImport && (
                    <div className="p-4 rounded-xl bg-white/[0.03] border border-white/[0.08] flex items-start gap-4 group">
                      <div className="p-2.5 rounded-lg bg-[#CC0033]/10 text-[#CC0033]">
                        <FileText size={20} />
                      </div>
                      <div className="flex-1 min-w-0">
                        <h4 className="text-sm font-medium text-white/90 truncate">
                          {transcriptImport.filename}
                        </h4>
                        <p className="text-xs text-white/40 mt-1">
                          {transcriptImport.university.short_name} • {transcriptImport.pages} page
                          {transcriptImport.pages === 1 ? "" : "s"} • {transcriptImport.match_count} matched course
                          {transcriptImport.match_count === 1 ? "" : "s"}
                        </p>
                      </div>
                    </div>
                  )}

                  <input
                    ref={fileInputRef}
                    type="file"
                    accept=".pdf,.txt,.md,.text"
                    className="hidden"
                    onChange={(e) => {
                      const file = e.target.files?.[0];
                      if (file) {
                        void handleTranscriptUpload(file);
                      }
                    }}
                  />

                  <button
                    onClick={() => fileInputRef.current?.click()}
                    disabled={uploading || !canImportTranscript}
                    className="w-full py-5 rounded-xl border border-dashed border-white/10 hover:border-[#CC0033]/50 hover:bg-[#CC0033]/5 transition-all text-sm text-white/60 flex flex-col items-center justify-center gap-2.5 group disabled:opacity-60 disabled:cursor-not-allowed"
                  >
                    <div className="p-2 rounded-full bg-white/[0.02] group-hover:bg-[#CC0033]/10 transition-colors">
                      <Upload size={18} className="text-white/40 group-hover:text-[#CC0033] transition-colors" />
                    </div>
                    <span>
                      {uploading
                        ? "Importing Transcript..."
                        : canImportTranscript
                          ? "Upload Unofficial Transcript"
                          : "Transcript Import Coming Soon"}
                    </span>
                    <span className="text-xs text-white/35">
                      {canImportTranscript
                        ? "Matches transcript lines to the selected university’s official catalog"
                        : "Search and official homepage discovery are enabled; transcript mapping is adapter-based"}
                    </span>
                  </button>

                  {uploadError && <p className="text-xs text-[#FFCDD6]">{uploadError}</p>}
                  {transcriptImport && (
                    <p className="text-xs text-white/40 leading-5">
                      Preview: {transcriptImport.text_preview.slice(0, 220)}
                      {transcriptImport.text_preview.length > 220 ? "..." : ""}
                    </p>
                  )}
                </div>
              </div>
            </div>
          </div>
        </motion.div>
      </div>
    </div>
  );
}
