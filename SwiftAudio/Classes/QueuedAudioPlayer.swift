//
//  QueuedAudioPlayer.swift
//  SwiftAudio
//
//  Created by Jørgen Henrichsen on 24/03/2018.
//

import Foundation
import MediaPlayer

/**
 An audio player that can keep track of a queue of AudioItems.
 */
public class QueuedAudioPlayer: AudioPlayer {

    // structure for emitted events when queued track playback ends
    public struct TrackEndedEvent {
        public let index: Int       // track index that ended
        public let position: Double // time position within this track
        public let nextIndex: Int?  // next track index (nil if end of queue)

        // shorthand initializer
        init(_ index: Int, _ position: Double, nextIndex: Int?) {
            self.index = index
            self.position = position
            self.nextIndex = nextIndex
        }
    }

    // structure for player state change events, including queue info
    public struct PlayerStateChangeEvent {
        public let state: AudioPlayerState
        public let currentIndex: Int
        public let currentTime: Double
    }
    

    public let queueManager: QueueManager = QueueManager<AudioItem>()
    
    /**
     Set wether the player should automatically play the next song when a song is finished.
     Default is `true`.
     */
    public var automaticallyPlayNextSong: Bool = true
    
    public override var currentItem: AudioItem? {
        return queueManager.current
    }
    
    /**
     The index of the current item.
     */
    public var currentIndex: Int {
        return queueManager.currentIndex
    }
    
     /**
     Stops the player and clears the queue.
     */
    public override func stop() {
        super.stop()
    }
    
    override func reset() {
        queueManager.clearQueue()
    }
    
    /**
     All items currently in the queue.
     */
    public var items: [AudioItem] {
        return queueManager.items
    }
    
    /**
     The previous items held by the queue.
     */
    public var previousItems: [AudioItem] {
        return queueManager.previousItems
    }
    
    /**
     The upcoming items in the queue.
     */
    public var nextItems: [AudioItem] {
        return queueManager.nextItems
    }
    
    /**
     Will replace the current item with a new one and load it into the player.
     
     - parameter item: The AudioItem to replace the current item.
     - throws: APError.LoadError
     */
    public override func load(item: AudioItem, playWhenReady: Bool) throws {
        try super.load(item: item, playWhenReady: playWhenReady)
        queueManager.replaceCurrentItem(with: item)
    }
    
    /**
     Add a single item to the queue.
     
     - parameter item: The item to add.
     - parameter playWhenReady: If the AudioPlayer has no item loaded, it will load the `item`. If this is `true` it will automatically start playback. Default is `true`.
     - throws: `APError`
     */
    public func add(item: AudioItem, playWhenReady: Bool = true) throws {
        if currentItem == nil {
            queueManager.addItem(item)
            try self.load(item: item, playWhenReady: playWhenReady)
        }
        else {
            queueManager.addItem(item)
        }
    }
    
    /**
     Add items to the queue.
     
     - parameter items: The items to add to the queue.
     - parameter playWhenReady: If the AudioPlayer has no item loaded, it will load the first item in the list. If this is `true` it will automatically start playback. Default is `true`.
     - throws: `APError`
     */
    public func add(items: [AudioItem], playWhenReady: Bool = true) throws {
        if currentItem == nil {
            queueManager.addItems(items)
            try self.load(item: currentItem!, playWhenReady: playWhenReady)
        }
        else {
            queueManager.addItems(items)
        }
    }
    
    public func add(items: [AudioItem], at index: Int) throws {
        try queueManager.addItems(items, at: index)
    }
    
    /**
     Step to the next item in the queue.
     
     - throws: `APError`
     */
    public func next() throws {
        emitPlaybackEndEvents(.skippedToNext)
        let nextItem = try queueManager.next()
        try self.load(item: nextItem, playWhenReady: true)
    }
    
    /**
     Step to the previous item in the queue.
     */
    public func previous() throws {
        emitPlaybackEndEvents(.skippedToPrevious)
        let previousItem = try queueManager.previous()
        try self.load(item: previousItem, playWhenReady: true)
    }
    
    /**
     Remove an item from the queue.
     
     - parameter index: The index of the item to remove.
     - throws: `APError.QueueError`
     */
    public func removeItem(at index: Int) throws {
        try queueManager.removeItem(at: index)
    }
    
    /**
     Jump to a certain item in the queue.
     
     - parameter index: The index of the item to jump to.
     - parameter playWhenReady: Wether the item should start playing when ready. Default is `true`.
     - throws: `APError`
     */
    public func jumpToItem(atIndex index: Int, playWhenReady: Bool = true) throws {
        emitPlaybackEndEvents(.jumpedToIndex, nextIndex: index)
        let item = try queueManager.jump(to: index)
        try self.load(item: item, playWhenReady: playWhenReady)
    }
    
    /**
     Move an item in the queue from one position to another.
     
     - parameter fromIndex: The index of the item to move.
     - parameter toIndex: The index to move the item to.
     - throws: `APError.QueueError`
     */
    func moveItem(fromIndex: Int, toIndex: Int) throws {
        try queueManager.moveItem(fromIndex: fromIndex, toIndex: toIndex)
    }
    
    /**
     Remove all upcoming items, those returned by `next()`
     */
    public func removeUpcomingItems() {
        queueManager.removeUpcomingItems()
    }
    
    /**
     Remove all previous items, those returned by `previous()`
     */
    public func removePreviousItems() {
        queueManager.removePreviousItems()
    }

    /**
     Emit event for playback end for current item.  We'll emit an event for the queue, and one for the track.
     */
    func emitPlaybackEndEvents(_ reason: PlaybackEndedReason, nextIndex: Int? = nil) {

        // emit the event for the track
        event.playbackEnd.emit(data: reason)

        // emit the event for the queue manager
        let toIndex: Int?
        switch reason {
        case .playedUntilEnd:
            return      // no queue manager event for this (track) event
        case .playerStopped:
            return      // no queue manager event for this (track) event
        case .skippedToNext:
            toIndex = currentIndex+1 >= items.count ? nil : currentIndex+1
        case .skippedToPrevious:
            toIndex = max(0, currentIndex-1)
        case .jumpedToIndex:
            toIndex = nextIndex==nil ? nil : max(0, min(nextIndex!, items.count-1))
        }

        // emit the queue event for track ended
        event.queueTrackEnded.emit(data:
            TrackEndedEvent(currentIndex, currentTime, nextIndex: toIndex))
    }
    
    // MARK: - AVPlayerWrapperDelegate
    
    override func AVWrapperItemDidPlayToEndTime() {
        super.AVWrapperItemDidPlayToEndTime()
        if automaticallyPlayNextSong {
            try? self.next()
        }
    }
    
}
