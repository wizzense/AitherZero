/**
 * Intelligent Caching System for AitherZero MCP Server
 * Provides smart caching, prefetching, and cache optimization
 */

export class IntelligentCaching {
  constructor(logger, analytics) {
    this.logger = logger;
    this.analytics = analytics;
    
    this.caches = {
      toolResults: new Map(),      // Tool execution results
      moduleStates: new Map(),     // Module state cache
      systemInfo: new Map(),       // System information cache
      workflows: new Map(),        // Workflow template cache
      predictions: new Map()       // Prediction cache
    };

    this.cacheMetrics = {
      hits: 0,
      misses: 0,
      evictions: 0,
      prefetches: 0,
      totalRequests: 0
    };

    this.config = {
      maxCacheSize: 1000,          // Maximum items per cache
      defaultTTL: 5 * 60 * 1000,   // 5 minutes default TTL
      maxMemoryUsage: 100 * 1024 * 1024, // 100MB max memory
      prefetchThreshold: 0.7,      // Prefetch when confidence > 70%
      evictionPolicy: 'LRU'        // Least Recently Used
    };

    this.initializeCaching();
  }

  initializeCaching() {
    // Set up cache cleaning intervals
    setInterval(() => this.cleanExpiredEntries(), 60 * 1000); // Clean every minute
    setInterval(() => this.optimizeCaches(), 5 * 60 * 1000);  // Optimize every 5 minutes
    
    // Initialize smart prefetching
    this.prefetchPredictor = new PrefetchPredictor(this.logger, this.analytics);
    
    this.logger.info('Intelligent caching system initialized');
  }

  // Main caching interface
  async get(cacheType, key, generator, options = {}) {
    const startTime = Date.now();
    this.cacheMetrics.totalRequests++;

    try {
      const cache = this.caches[cacheType];
      if (!cache) {
        throw new Error(`Unknown cache type: ${cacheType}`);
      }

      const cacheKey = this.generateCacheKey(key, options);
      const cached = cache.get(cacheKey);

      // Cache hit
      if (cached && !this.isExpired(cached)) {
        this.cacheMetrics.hits++;
        this.updateAccessTime(cached);
        
        this.logger.debug(`Cache hit for ${cacheType}:${cacheKey}`, {
          age: Date.now() - cached.createdAt,
          accessCount: cached.accessCount
        });

        return cached.data;
      }

      // Cache miss - generate new data
      this.cacheMetrics.misses++;
      this.logger.debug(`Cache miss for ${cacheType}:${cacheKey}`);

      const newData = await generator();
      await this.set(cacheType, key, newData, options);

      // Trigger smart prefetching based on usage patterns
      this.considerPrefetching(cacheType, key, options);

      return newData;

    } catch (error) {
      this.logger.error(`Cache operation failed for ${cacheType}:${key}`, error);
      throw error;
    } finally {
      const duration = Date.now() - startTime;
      this.recordCachePerformance(cacheType, duration);
    }
  }

  async set(cacheType, key, data, options = {}) {
    const cache = this.caches[cacheType];
    if (!cache) {
      throw new Error(`Unknown cache type: ${cacheType}`);
    }

    const cacheKey = this.generateCacheKey(key, options);
    const ttl = options.ttl || this.getDefaultTTL(cacheType);
    const priority = options.priority || this.calculatePriority(cacheType, key, data);

    const cacheEntry = {
      data,
      key: cacheKey,
      createdAt: Date.now(),
      expiresAt: Date.now() + ttl,
      accessCount: 0,
      lastAccessed: Date.now(),
      size: this.calculateSize(data),
      priority,
      metadata: {
        cacheType,
        originalKey: key,
        options,
        generationTime: options.generationTime || 0
      }
    };

    // Check if we need to evict entries
    if (cache.size >= this.config.maxCacheSize) {
      await this.evictEntries(cacheType, 1);
    }

    cache.set(cacheKey, cacheEntry);

    this.logger.debug(`Cached ${cacheType}:${cacheKey}`, {
      size: cacheEntry.size,
      ttl,
      priority
    });

    // Update cache analytics
    this.analytics?.trackCacheOperation?.('set', cacheType, cacheKey, cacheEntry.size);
  }

  // Smart cache invalidation
  async invalidate(cacheType, pattern) {
    const cache = this.caches[cacheType];
    if (!cache) {
      return;
    }

    let invalidatedCount = 0;

    if (typeof pattern === 'string') {
      // Exact key match
      if (cache.delete(pattern)) {
        invalidatedCount = 1;
      }
    } else if (pattern instanceof RegExp) {
      // Pattern-based invalidation
      for (const [key, entry] of cache.entries()) {
        if (pattern.test(key) || pattern.test(entry.metadata.originalKey)) {
          cache.delete(key);
          invalidatedCount++;
        }
      }
    } else if (typeof pattern === 'function') {
      // Function-based invalidation
      for (const [key, entry] of cache.entries()) {
        if (pattern(key, entry)) {
          cache.delete(key);
          invalidatedCount++;
        }
      }
    }

    if (invalidatedCount > 0) {
      this.logger.info(`Invalidated ${invalidatedCount} entries from ${cacheType} cache`);
    }
  }

  // Intelligent prefetching
  async prefetch(cacheType, predictions) {
    for (const prediction of predictions) {
      if (prediction.confidence < this.config.prefetchThreshold) {
        continue;
      }

      try {
        const cache = this.caches[cacheType];
        const cacheKey = this.generateCacheKey(prediction.key, prediction.options);

        // Skip if already cached
        if (cache.has(cacheKey)) {
          continue;
        }

        // Execute prefetch in background
        this.backgroundPrefetch(cacheType, prediction);
        this.cacheMetrics.prefetches++;

      } catch (error) {
        this.logger.warn(`Prefetch failed for ${cacheType}:${prediction.key}`, error);
      }
    }
  }

  async backgroundPrefetch(cacheType, prediction) {
    try {
      // Generate data based on prediction
      const data = await this.generatePrefetchData(cacheType, prediction);
      
      await this.set(cacheType, prediction.key, data, {
        ...prediction.options,
        ttl: prediction.ttl || this.config.defaultTTL,
        priority: 'prefetch'
      });

      this.logger.debug(`Prefetched ${cacheType}:${prediction.key}`, {
        confidence: prediction.confidence,
        size: this.calculateSize(data)
      });

    } catch (error) {
      this.logger.warn(`Background prefetch failed for ${cacheType}:${prediction.key}`, error);
    }
  }

  // Cache optimization and maintenance
  async optimizeCaches() {
    const startTime = Date.now();
    let totalOptimized = 0;

    for (const [cacheType, cache] of Object.entries(this.caches)) {
      const optimized = await this.optimizeCache(cacheType, cache);
      totalOptimized += optimized;
    }

    const duration = Date.now() - startTime;
    this.logger.info(`Cache optimization completed`, {
      totalOptimized,
      duration,
      cacheStats: this.getCacheStats()
    });
  }

  async optimizeCache(cacheType, cache) {
    let optimizedCount = 0;

    // Remove expired entries
    const expired = this.cleanExpiredEntries(cache);
    optimizedCount += expired;

    // Check memory usage and evict if necessary
    const memoryUsage = this.calculateCacheMemoryUsage(cache);
    if (memoryUsage > this.config.maxMemoryUsage / Object.keys(this.caches).length) {
      const evicted = await this.evictByMemoryPressure(cacheType, cache);
      optimizedCount += evicted;
    }

    // Compress cache entries if beneficial
    const compressed = await this.compressCacheEntries(cache);
    optimizedCount += compressed;

    return optimizedCount;
  }

  cleanExpiredEntries(cache = null) {
    let totalCleaned = 0;
    const caches = cache ? [cache] : Object.values(this.caches);

    for (const cacheInstance of caches) {
      const expired = [];
      
      for (const [key, entry] of cacheInstance.entries()) {
        if (this.isExpired(entry)) {
          expired.push(key);
        }
      }

      for (const key of expired) {
        cacheInstance.delete(key);
        totalCleaned++;
      }
    }

    if (totalCleaned > 0) {
      this.logger.debug(`Cleaned ${totalCleaned} expired cache entries`);
    }

    return totalCleaned;
  }

  async evictEntries(cacheType, count) {
    const cache = this.caches[cacheType];
    if (!cache) return 0;

    const entries = Array.from(cache.entries());
    
    // Sort by eviction priority (LRU + priority)
    entries.sort((a, b) => {
      const [keyA, entryA] = a;
      const [keyB, entryB] = b;
      
      // Higher priority = less likely to evict
      const priorityDiff = this.getPriorityScore(entryA) - this.getPriorityScore(entryB);
      if (priorityDiff !== 0) return priorityDiff;
      
      // Older access time = more likely to evict
      return entryA.lastAccessed - entryB.lastAccessed;
    });

    let evicted = 0;
    for (let i = 0; i < Math.min(count, entries.length); i++) {
      const [key, entry] = entries[i];
      cache.delete(key);
      evicted++;
      
      this.logger.debug(`Evicted cache entry ${cacheType}:${key}`, {
        age: Date.now() - entry.createdAt,
        accessCount: entry.accessCount,
        priority: entry.priority
      });
    }

    this.cacheMetrics.evictions += evicted;
    return evicted;
  }

  // Cache analytics and monitoring
  getCacheStats() {
    const stats = {
      overall: { ...this.cacheMetrics },
      byType: {},
      performance: {
        hitRate: this.cacheMetrics.totalRequests > 0 
          ? (this.cacheMetrics.hits / this.cacheMetrics.totalRequests * 100).toFixed(2) + '%'
          : '0%',
        missRate: this.cacheMetrics.totalRequests > 0 
          ? (this.cacheMetrics.misses / this.cacheMetrics.totalRequests * 100).toFixed(2) + '%'
          : '0%'
      }
    };

    for (const [type, cache] of Object.entries(this.caches)) {
      const memoryUsage = this.calculateCacheMemoryUsage(cache);
      const avgAge = this.calculateAverageAge(cache);
      
      stats.byType[type] = {
        size: cache.size,
        memoryUsage,
        avgAge,
        oldestEntry: this.getOldestEntry(cache),
        newestEntry: this.getNewestEntry(cache)
      };
    }

    return stats;
  }

  generateCacheReport() {
    const stats = this.getCacheStats();
    const recommendations = this.generateCacheRecommendations(stats);

    return {
      timestamp: new Date().toISOString(),
      stats,
      recommendations,
      config: this.config,
      prefetchPredictions: this.prefetchPredictor.getRecentPredictions()
    };
  }

  generateCacheRecommendations(stats) {
    const recommendations = [];

    // Hit rate recommendations
    const hitRate = parseFloat(stats.performance.hitRate);
    if (hitRate < 50) {
      recommendations.push({
        type: 'performance',
        priority: 'high',
        message: `Low cache hit rate (${hitRate}%) - consider increasing TTL or cache size`,
        action: 'tune_cache_parameters'
      });
    }

    // Memory usage recommendations
    for (const [type, typeStats] of Object.entries(stats.byType)) {
      if (typeStats.memoryUsage > this.config.maxMemoryUsage * 0.8) {
        recommendations.push({
          type: 'memory',
          priority: 'medium',
          message: `High memory usage in ${type} cache (${(typeStats.memoryUsage / 1024 / 1024).toFixed(2)}MB)`,
          action: 'reduce_cache_size'
        });
      }
    }

    // Prefetch recommendations
    if (this.cacheMetrics.prefetches > 0) {
      const prefetchHitRate = this.prefetchPredictor.getHitRate();
      if (prefetchHitRate < 30) {
        recommendations.push({
          type: 'prefetch',
          priority: 'low',
          message: `Low prefetch hit rate (${prefetchHitRate}%) - consider tuning prediction algorithms`,
          action: 'tune_prefetch_algorithm'
        });
      }
    }

    return recommendations;
  }

  // Helper methods
  generateCacheKey(key, options) {
    if (typeof key === 'string') {
      const optionsHash = this.hashObject(options);
      return `${key}:${optionsHash}`;
    }
    
    return this.hashObject({ key, options });
  }

  hashObject(obj) {
    // Simple hash function for object serialization
    const str = JSON.stringify(obj, Object.keys(obj).sort());
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
      const char = str.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash; // Convert to 32-bit integer
    }
    return hash.toString(36);
  }

  isExpired(entry) {
    return Date.now() > entry.expiresAt;
  }

  updateAccessTime(entry) {
    entry.lastAccessed = Date.now();
    entry.accessCount++;
  }

  calculateSize(data) {
    // Rough size calculation
    return JSON.stringify(data).length * 2; // Approximate UTF-16 size
  }

  calculatePriority(cacheType, key, data) {
    // Dynamic priority calculation based on type and content
    const basePriority = {
      toolResults: 5,
      moduleStates: 8,
      systemInfo: 3,
      workflows: 7,
      predictions: 4
    };

    let priority = basePriority[cacheType] || 5;

    // Adjust based on data characteristics
    if (data && typeof data === 'object') {
      if (data.success === false) priority -= 2; // Failed results less important
      if (data.executionTime > 10000) priority += 2; // Expensive operations more important
    }

    return Math.max(1, Math.min(10, priority));
  }

  getPriorityScore(entry) {
    // Combine priority with access patterns
    const basePriority = entry.priority || 5;
    const accessBonus = Math.min(2, entry.accessCount / 10);
    const ageNegative = Math.min(2, (Date.now() - entry.createdAt) / (24 * 60 * 60 * 1000));
    
    return basePriority + accessBonus - ageNegative;
  }

  getDefaultTTL(cacheType) {
    const ttlMap = {
      toolResults: 10 * 60 * 1000,    // 10 minutes
      moduleStates: 5 * 60 * 1000,    // 5 minutes
      systemInfo: 2 * 60 * 1000,      // 2 minutes
      workflows: 30 * 60 * 1000,      // 30 minutes
      predictions: 15 * 60 * 1000     // 15 minutes
    };

    return ttlMap[cacheType] || this.config.defaultTTL;
  }

  calculateCacheMemoryUsage(cache) {
    let totalSize = 0;
    for (const entry of cache.values()) {
      totalSize += entry.size || 0;
    }
    return totalSize;
  }

  calculateAverageAge(cache) {
    if (cache.size === 0) return 0;
    
    let totalAge = 0;
    const now = Date.now();
    
    for (const entry of cache.values()) {
      totalAge += now - entry.createdAt;
    }
    
    return totalAge / cache.size;
  }

  getOldestEntry(cache) {
    let oldest = null;
    for (const entry of cache.values()) {
      if (!oldest || entry.createdAt < oldest.createdAt) {
        oldest = entry;
      }
    }
    return oldest ? { age: Date.now() - oldest.createdAt, key: oldest.key } : null;
  }

  getNewestEntry(cache) {
    let newest = null;
    for (const entry of cache.values()) {
      if (!newest || entry.createdAt > newest.createdAt) {
        newest = entry;
      }
    }
    return newest ? { age: Date.now() - newest.createdAt, key: newest.key } : null;
  }

  considerPrefetching(cacheType, key, options) {
    // Trigger smart prefetching based on access patterns
    this.prefetchPredictor.recordAccess(cacheType, key, options);
    
    const predictions = this.prefetchPredictor.getPredictions(cacheType, key);
    if (predictions.length > 0) {
      this.prefetch(cacheType, predictions);
    }
  }

  async generatePrefetchData(cacheType, prediction) {
    // This would be implemented based on the specific prediction type
    // For now, return placeholder data
    return {
      prefetched: true,
      prediction: prediction.key,
      timestamp: Date.now()
    };
  }

  recordCachePerformance(cacheType, duration) {
    // Record performance metrics for analytics
    this.analytics?.trackCachePerformance?.(cacheType, duration);
  }

  async evictByMemoryPressure(cacheType, cache) {
    const targetReduction = this.config.maxMemoryUsage * 0.2; // Reduce by 20%
    let evicted = 0;
    let freedMemory = 0;

    const entries = Array.from(cache.entries())
      .sort((a, b) => this.getPriorityScore(a[1]) - this.getPriorityScore(b[1]));

    for (const [key, entry] of entries) {
      if (freedMemory >= targetReduction) break;
      
      cache.delete(key);
      evicted++;
      freedMemory += entry.size || 0;
    }

    return evicted;
  }

  async compressCacheEntries(cache) {
    // Placeholder for cache compression logic
    // Could implement data compression for large entries
    return 0;
  }
}

// Prefetch prediction system
class PrefetchPredictor {
  constructor(logger, analytics) {
    this.logger = logger;
    this.analytics = analytics;
    this.accessPatterns = new Map();
    this.sequencePatterns = new Map();
    this.recentPredictions = [];
    this.predictionHits = 0;
    this.totalPredictions = 0;
  }

  recordAccess(cacheType, key, options) {
    const timestamp = Date.now();
    const accessKey = `${cacheType}:${key}`;

    // Record individual access
    if (!this.accessPatterns.has(accessKey)) {
      this.accessPatterns.set(accessKey, {
        count: 0,
        lastAccess: timestamp,
        intervals: [],
        options: []
      });
    }

    const pattern = this.accessPatterns.get(accessKey);
    
    if (pattern.lastAccess) {
      const interval = timestamp - pattern.lastAccess;
      pattern.intervals.push(interval);
      
      // Keep only last 10 intervals
      if (pattern.intervals.length > 10) {
        pattern.intervals.shift();
      }
    }

    pattern.count++;
    pattern.lastAccess = timestamp;
    pattern.options.push(options);

    // Record sequence patterns
    this.recordSequencePattern(cacheType, key, timestamp);
  }

  recordSequencePattern(cacheType, key, timestamp) {
    const sequenceKey = cacheType;
    
    if (!this.sequencePatterns.has(sequenceKey)) {
      this.sequencePatterns.set(sequenceKey, {
        sequence: [],
        patterns: new Map()
      });
    }

    const sequence = this.sequencePatterns.get(sequenceKey);
    sequence.sequence.push({ key, timestamp });

    // Keep only last 20 accesses for pattern detection
    if (sequence.sequence.length > 20) {
      sequence.sequence.shift();
    }

    // Detect patterns in the sequence
    this.detectSequencePatterns(sequence);
  }

  detectSequencePatterns(sequence) {
    const seq = sequence.sequence;
    if (seq.length < 3) return;

    // Look for repeating patterns of length 2-5
    for (let patternLength = 2; patternLength <= Math.min(5, Math.floor(seq.length / 2)); patternLength++) {
      for (let i = 0; i <= seq.length - patternLength * 2; i++) {
        const pattern = seq.slice(i, i + patternLength).map(item => item.key);
        const nextPattern = seq.slice(i + patternLength, i + patternLength * 2).map(item => item.key);
        
        if (this.arraysEqual(pattern, nextPattern)) {
          const patternKey = pattern.join('->');
          
          if (!sequence.patterns.has(patternKey)) {
            sequence.patterns.set(patternKey, { count: 0, confidence: 0 });
          }
          
          const patternInfo = sequence.patterns.get(patternKey);
          patternInfo.count++;
          patternInfo.confidence = Math.min(1.0, patternInfo.count / 10);
        }
      }
    }
  }

  getPredictions(cacheType, currentKey) {
    const predictions = [];

    // Get predictions based on access patterns
    const intervalPredictions = this.getIntervalBasedPredictions(cacheType, currentKey);
    predictions.push(...intervalPredictions);

    // Get predictions based on sequence patterns
    const sequencePredictions = this.getSequenceBasedPredictions(cacheType, currentKey);
    predictions.push(...sequencePredictions);

    // Filter and sort predictions
    return predictions
      .filter(p => p.confidence >= 0.3)
      .sort((a, b) => b.confidence - a.confidence)
      .slice(0, 5); // Top 5 predictions
  }

  getIntervalBasedPredictions(cacheType, currentKey) {
    const predictions = [];
    const accessKey = `${cacheType}:${currentKey}`;
    const pattern = this.accessPatterns.get(accessKey);

    if (!pattern || pattern.intervals.length < 2) {
      return predictions;
    }

    // Calculate average interval
    const avgInterval = pattern.intervals.reduce((sum, interval) => sum + interval, 0) / pattern.intervals.length;
    const variance = this.calculateVariance(pattern.intervals, avgInterval);
    const confidence = Math.max(0, 1 - (variance / (avgInterval * avgInterval)));

    if (confidence > 0.3) {
      predictions.push({
        key: currentKey,
        cacheType,
        predictedTime: Date.now() + avgInterval,
        confidence,
        type: 'interval',
        options: pattern.options[pattern.options.length - 1] || {}
      });
    }

    return predictions;
  }

  getSequenceBasedPredictions(cacheType, currentKey) {
    const predictions = [];
    const sequence = this.sequencePatterns.get(cacheType);

    if (!sequence) return predictions;

    // Find patterns that start with current key
    for (const [patternKey, patternInfo] of sequence.patterns) {
      const pattern = patternKey.split('->');
      
      if (pattern[0] === currentKey && pattern.length > 1) {
        const nextKey = pattern[1];
        
        predictions.push({
          key: nextKey,
          cacheType,
          predictedTime: Date.now() + 5000, // 5 seconds ahead
          confidence: patternInfo.confidence,
          type: 'sequence',
          options: {}
        });
      }
    }

    return predictions;
  }

  calculateVariance(values, mean) {
    const squaredDiffs = values.map(value => Math.pow(value - mean, 2));
    return squaredDiffs.reduce((sum, diff) => sum + diff, 0) / values.length;
  }

  arraysEqual(a, b) {
    return a.length === b.length && a.every((val, index) => val === b[index]);
  }

  recordPredictionHit(prediction) {
    this.predictionHits++;
    this.totalPredictions++;
    
    this.logger.debug('Prefetch prediction hit', {
      key: prediction.key,
      type: prediction.type,
      confidence: prediction.confidence
    });
  }

  recordPredictionMiss(prediction) {
    this.totalPredictions++;
    
    this.logger.debug('Prefetch prediction miss', {
      key: prediction.key,
      type: prediction.type,
      confidence: prediction.confidence
    });
  }

  getHitRate() {
    return this.totalPredictions > 0 ? (this.predictionHits / this.totalPredictions * 100) : 0;
  }

  getRecentPredictions() {
    return this.recentPredictions.slice(-20); // Last 20 predictions
  }
}